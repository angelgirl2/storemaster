using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Models;
using StoreMaster.Server.Services;
using System.Text.Json;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/sync")]
public sealed class SyncController : ControllerBase
{
    readonly StoreMasterDbContext db;
    public SyncController(StoreMasterDbContext db) => this.db = db;
    int Sid() => int.TryParse(User.FindFirst("storeId")?.Value, out var sid) ? sid : 0;
    int Uid() => int.TryParse(User.FindFirst("sub")?.Value, out var uid) ? uid : 0;

    [HttpPost("push")]
    public async Task<IActionResult> Push([FromBody] PushDto x)
    {
        if (x?.Changes == null || x.Changes.Count > 2000)
            return BadRequest(new { message = "بسته همگام‌سازی نامعتبر است." });
        var sid = Sid();
        if (sid <= 0 || Uid() <= 0) return Unauthorized();
        foreach (var c in x.Changes)
        {
            db.SyncChanges.Add(new SyncChange { StoreId = sid, UserId = Uid(), Entity = c.Entity, Operation = c.Operation, EntityId = c.EntityId, PayloadJson = c.PayloadJson });
        }
        await db.SaveChangesAsync();

        // Local sales remain usable offline. When they eventually reach the server,
        // publish one deduplicated store notification for each sale entity.
        foreach (var c in x.Changes.Where(IsSaleEntity))
        {
            if (c.Operation.Equals("DELETE", StringComparison.OrdinalIgnoreCase) || !PayloadIsSale(c.PayloadJson)) continue;
            await AppNotificationStore.PublishAsync(db, sid, "sale_created", "فروش جدید همگام‌سازی شد",
                $"فروش {c.EntityId} از یک دستگاه فروشگاه همگام‌سازی شد.",
                JsonSerializer.Serialize(new { entity = c.Entity, entityId = c.EntityId }),
                $"sale:{sid}:{c.Entity}:{c.EntityId}");
        }
        return Ok(new { success = true, accepted = x.Changes.Count, lastCursor = await db.SyncChanges.Where(x => x.StoreId == sid).MaxAsync(x => (long?)x.Id) ?? 0 });
    }

    [HttpGet("pull")]
    public async Task<IActionResult> Pull(long cursor = 0)
    {
        var sid = Sid();
        var items = await db.SyncChanges.Where(x => x.StoreId == sid && x.Id > cursor).OrderBy(x => x.Id).Take(500)
            .Select(x => new { id = x.Id, entity = x.Entity, operation = x.Operation, entityId = x.EntityId, payload = x.PayloadJson }).ToListAsync();
        return Ok(new { items, lastCursor = items.Count == 0 ? cursor : items.Max(x => x.id) });
    }

    static bool IsSaleEntity(ChangeDto c)
    {
        var entity = (c.Entity ?? string.Empty).ToLowerInvariant();
        return entity is "transactions" or "store_transactions" or "sales" or "invoices" or "sale";
    }

    static bool PayloadIsSale(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Object) return false;
            foreach (var property in doc.RootElement.EnumerateObject())
                if (property.Name.Equals("type", StringComparison.OrdinalIgnoreCase) &&
                    property.Value.ValueKind == JsonValueKind.String &&
                    property.Value.GetString()?.Equals("SALE", StringComparison.OrdinalIgnoreCase) == true) return true;
            // A dedicated sales/invoices entity may omit a transaction type field.
            return false;
        }
        catch { return false; }
    }
}

public sealed record PushDto(List<ChangeDto> Changes);
public sealed record ChangeDto(string Entity, string Operation, string EntityId, string PayloadJson);

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
[Route("api/v1/cloud-sync")]
public class CloudSyncController : ControllerBase
{
    readonly StoreMasterDbContext db;
    public CloudSyncController(StoreMasterDbContext db) => this.db = db;
    int Sid() => int.Parse(User.FindFirst("storeId")?.Value ?? "0");
    int Uid() => int.Parse(User.FindFirst("sub")?.Value ?? "0");

    [HttpPost("push")]
    public async Task<IActionResult> Push([FromBody] CloudPushDto x)
    {
        var sid = Sid();
        if (sid <= 0 || Uid() <= 0) return Unauthorized();
        var submittedItems = x.Items ?? new List<CloudItemDto>();
        foreach (var item in submittedItems)
        {
            var existing = await db.CloudRecords.FirstOrDefaultAsync(z => z.StoreId == sid && z.Entity == item.Entity && z.EntityId == item.EntityId);
            if (existing == null)
            {
                db.CloudRecords.Add(new CloudRecord { StoreId = sid, UserId = Uid(), Entity = item.Entity, EntityId = item.EntityId, Operation = item.Operation, PayloadJson = item.PayloadJson, SourceVersion = item.SourceVersion, UpdatedAt = DateTime.UtcNow });
            }
            else if (item.SourceVersion > existing.SourceVersion)
            {
                existing.UserId = Uid(); existing.Operation = item.Operation; existing.PayloadJson = item.PayloadJson; existing.SourceVersion = item.SourceVersion; existing.UpdatedAt = DateTime.UtcNow;
            }
        }
        await db.SaveChangesAsync();
        foreach (var item in submittedItems.Where(IsSaleEntity))
        {
            if (item.Operation.Equals("DELETE", StringComparison.OrdinalIgnoreCase) || !PayloadIsSale(item.PayloadJson)) continue;
            await AppNotificationStore.PublishAsync(db, sid, "sale_created", "فروش جدید همگام‌سازی شد",
                $"فروش {item.EntityId} از یک دستگاه فروشگاه همگام‌سازی شد.",
                JsonSerializer.Serialize(new { entity = item.Entity, entityId = item.EntityId }),
                $"sale:{sid}:{item.Entity}:{item.EntityId}");
        }
        foreach (var item in submittedItems.Where(IsNotificationEvent))
        {
            if (item.Operation.Equals("DELETE", StringComparison.OrdinalIgnoreCase)) continue;
            if (!TryReadNotificationEvent(item.PayloadJson, out var eventType, out var title, out var message, out var entityId, out var metadata)) continue;
            var dedupeKey = eventType == "sale_created" && !string.IsNullOrWhiteSpace(entityId)
                ? $"sale:{sid}:transactions:{entityId}"
                : $"client-event:{sid}:{item.EntityId}";
            await AppNotificationStore.PublishAsync(db, sid, eventType, title, message, metadata, dedupeKey);
        }
        return Ok(new { success = true, accepted = x.Items?.Count ?? 0, serverTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() });
    }

    static bool IsSaleEntity(CloudItemDto item)
    {
        var entity = (item.Entity ?? string.Empty).ToLowerInvariant();
        return entity is "transactions" or "store_transactions" or "sales" or "invoices" or "sale";
    }

    static bool IsNotificationEvent(CloudItemDto item) =>
        string.Equals(item.Entity, "notification_events", StringComparison.OrdinalIgnoreCase);

    static bool TryReadNotificationEvent(string json, out string eventType, out string title,
        out string message, out string? entityId, out string metadata)
    {
        eventType = title = message = string.Empty;
        entityId = null;
        metadata = "{}";
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Object) return false;
            var root = doc.RootElement;
            eventType = root.TryGetProperty("eventType", out var t) ? t.GetString() ?? string.Empty : string.Empty;
            title = root.TryGetProperty("title", out var ti) ? ti.GetString() ?? string.Empty : string.Empty;
            message = root.TryGetProperty("message", out var m) ? m.GetString() ?? string.Empty : string.Empty;
            entityId = root.TryGetProperty("entityId", out var e) && e.ValueKind == JsonValueKind.String ? e.GetString() : null;
            metadata = json;
            var allowed = new HashSet<string>(StringComparer.Ordinal)
                { "sale_created", "receipt_printed", "invoice_printed", "sync_completed", "support_opened" };
            return allowed.Contains(eventType) && !string.IsNullOrWhiteSpace(title) && !string.IsNullOrWhiteSpace(message);
        }
        catch { return false; }
    }

    static bool PayloadIsSale(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Object) return false;
            foreach (var property in doc.RootElement.EnumerateObject())
                if (property.Name.Equals("type", StringComparison.OrdinalIgnoreCase) && property.Value.ValueKind == JsonValueKind.String && property.Value.GetString()?.Equals("SALE", StringComparison.OrdinalIgnoreCase) == true) return true;
            return false;
        }
        catch { return false; }
    }

    [HttpGet("snapshot")]
    public async Task<IActionResult> Snapshot()
    {
        var rows = await db.CloudRecords.AsNoTracking().Where(x => x.StoreId == Sid()).OrderBy(x => x.Id).ToListAsync();
        return Ok(new { items = rows.Select(x => new { id = x.Id, entity = x.Entity, entityId = x.EntityId, operation = x.Operation, payload = JsonSerializer.Deserialize<JsonElement>(x.PayloadJson), version = x.SourceVersion, updatedAt = new DateTimeOffset(x.UpdatedAt).ToUnixTimeMilliseconds() }), serverTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() });
    }
}
public record CloudPushDto(List<CloudItemDto>? Items);
public record CloudItemDto(string Entity,string EntityId,string Operation,string PayloadJson,long SourceVersion);

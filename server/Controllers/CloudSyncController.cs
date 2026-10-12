using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Models;
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
        foreach (var item in x.Items ?? new())
        {
            var existing = await db.CloudRecords.FirstOrDefaultAsync(z => z.StoreId == sid && z.Entity == item.Entity && z.EntityId == item.EntityId);
            if (existing == null)
            {
                db.CloudRecords.Add(new CloudRecord { StoreId = sid, UserId = Uid(), Entity = item.Entity, EntityId = item.EntityId, Operation = item.Operation, PayloadJson = item.PayloadJson, SourceVersion = item.SourceVersion, UpdatedAt = DateTime.UtcNow });
            }
            else if (item.SourceVersion >= existing.SourceVersion)
            {
                existing.UserId = Uid(); existing.Operation = item.Operation; existing.PayloadJson = item.PayloadJson; existing.SourceVersion = item.SourceVersion; existing.UpdatedAt = DateTime.UtcNow;
            }
        }
        await db.SaveChangesAsync();
        return Ok(new { success = true, accepted = x.Items?.Count ?? 0, serverTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() });
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

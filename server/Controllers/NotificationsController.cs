using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Services;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Data.Common;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("api/v1/notifications")]
public sealed class NotificationsController : ControllerBase
{
    private readonly StoreMasterDbContext db;
    private readonly IConfiguration cfg;

    public NotificationsController(StoreMasterDbContext db, IConfiguration cfg)
    {
        this.db = db;
        this.cfg = cfg;
    }

    [Authorize]
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] long afterId = 0, [FromQuery] int take = 50)
    {
        if (!TryContext(out var storeId, out var userId)) return Unauthorized();
        await AppNotificationStore.EnsureSchemaAsync(db, HttpContext.RequestAborted);
        take = Math.Clamp(take, 1, 100);
        var conn = db.Database.GetDbConnection();
        var openedHere = conn.State != System.Data.ConnectionState.Open;
        if (openedHere) await conn.OpenAsync(HttpContext.RequestAborted);
        try
        {
            await using var cmd = conn.CreateCommand();
            // First poll returns the most recent page; later polls return only newer rows.
            var order = afterId <= 0 ? "DESC" : "ASC";
            cmd.CommandText = $"""
                SELECT n."Id", n."EventType", n."Title", n."Message", n."MetadataJson", n."CreatedAt",
                       (r."NotificationId" IS NOT NULL) AS "IsRead"
                FROM "AppNotifications" n
                LEFT JOIN "AppNotificationReceipts" r
                  ON r."NotificationId" = n."Id" AND r."UserId" = @userId
                WHERE (n."StoreId" IS NULL OR n."StoreId" = @storeId)
                  AND (@afterId <= 0 OR n."Id" > @afterId)
                ORDER BY n."Id" {order}
                LIMIT @take
                """;
            Add(cmd, "storeId", storeId);
            Add(cmd, "userId", userId);
            Add(cmd, "afterId", Math.Max(0, afterId));
            Add(cmd, "take", take);

            var items = new List<object>();
            long lastId = Math.Max(0, afterId);
            await using var reader = await cmd.ExecuteReaderAsync(HttpContext.RequestAborted);
            while (await reader.ReadAsync(HttpContext.RequestAborted))
            {
                var id = reader.GetInt64(0);
                lastId = Math.Max(lastId, id);
                items.Add(new
                {
                    id,
                    eventType = reader.GetString(1),
                    title = reader.GetString(2),
                    message = reader.GetString(3),
                    metadata = SafeJson(reader.GetString(4)),
                    createdAt = ToUnixMillis(reader.GetValue(5)),
                    isRead = reader.GetBoolean(6)
                });
            }
            return Ok(new { items, lastId });
        }
        finally
        {
            if (openedHere) await conn.CloseAsync();
        }
    }

    [Authorize]
    [HttpGet("unread-count")]
    public async Task<IActionResult> UnreadCount()
    {
        if (!TryContext(out var storeId, out var userId)) return Unauthorized();
        await AppNotificationStore.EnsureSchemaAsync(db, HttpContext.RequestAborted);
        var conn = db.Database.GetDbConnection();
        var openedHere = conn.State != System.Data.ConnectionState.Open;
        if (openedHere) await conn.OpenAsync(HttpContext.RequestAborted);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = """
                SELECT COUNT(*)
                FROM "AppNotifications" n
                LEFT JOIN "AppNotificationReceipts" r
                  ON r."NotificationId" = n."Id" AND r."UserId" = @userId
                WHERE (n."StoreId" IS NULL OR n."StoreId" = @storeId)
                  AND r."NotificationId" IS NULL
                """;
            Add(cmd, "storeId", storeId);
            Add(cmd, "userId", userId);
            var count = Convert.ToInt32(await cmd.ExecuteScalarAsync(HttpContext.RequestAborted));
            return Ok(new { count });
        }
        finally
        {
            if (openedHere) await conn.CloseAsync();
        }
    }

    [Authorize]
    [HttpPost("{id:long}/read")]
    public async Task<IActionResult> MarkRead(long id)
    {
        if (!TryContext(out var storeId, out var userId)) return Unauthorized();
        await AppNotificationStore.EnsureSchemaAsync(db, HttpContext.RequestAborted);
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO "AppNotificationReceipts" ("NotificationId", "UserId", "ReadAt")
            SELECT n."Id", {userId}, now()
            FROM "AppNotifications" n
            WHERE n."Id" = {id} AND (n."StoreId" IS NULL OR n."StoreId" = {storeId})
            ON CONFLICT ("NotificationId", "UserId") DO NOTHING
            """, HttpContext.RequestAborted);
        return Ok(new { success = true });
    }

    [Authorize]
    [HttpPost("events")]
    public async Task<IActionResult> PublishClientEvent([FromBody] ClientEventDto? x)
    {
        if (x == null) return BadRequest(new { message = "اطلاعات رویداد ارسال نشده است." });
        if (!TryContext(out var storeId, out _)) return Unauthorized();
        var eventType = (x.EventType ?? string.Empty).Trim().ToLowerInvariant();
        var allowed = new HashSet<string>(StringComparer.Ordinal)
        {
            "sale_created", "receipt_printed", "invoice_printed", "sync_completed", "support_opened"
        };
        if (!allowed.Contains(eventType)) return BadRequest(new { message = "نوع رویداد مجاز نیست." });
        var title = string.IsNullOrWhiteSpace(x.Title) ? DefaultTitle(eventType) : x.Title.Trim();
        var message = string.IsNullOrWhiteSpace(x.Message) ? title : x.Message.Trim();
        string? key = null;
        if (eventType == "sale_created" && !string.IsNullOrWhiteSpace(x.EntityId))
            key = $"sale:{storeId}:transactions:{x.EntityId.Trim()}";
        else if (!string.IsNullOrWhiteSpace(x.EventId))
            key = $"client-event:{storeId}:{x.EventId.Trim()}";
        await AppNotificationStore.PublishAsync(db, storeId, eventType, title, message,
            JsonSerializer.Serialize(new { entityId = x.EntityId, platform = x.Platform }), key, HttpContext.RequestAborted);
        return Ok(new { success = true });
    }

    [AllowAnonymous]
    [HttpPost("admin/publish")]
    public async Task<IActionResult> AdminPublish([FromBody] AdminNotificationDto? x)
    {
        if (!HasAdminKey()) return Unauthorized(new { message = "کلید مدیر معتبر نیست." });
        if (x == null || string.IsNullOrWhiteSpace(x.Title) || string.IsNullOrWhiteSpace(x.Message))
            return BadRequest(new { message = "عنوان و متن اعلان الزامی است." });
        if (x.StoreId is <= 0) return BadRequest(new { message = "شناسه فروشگاه نامعتبر است." });
        await AppNotificationStore.PublishAsync(db, x.StoreId, string.IsNullOrWhiteSpace(x.EventType) ? "admin_message" : x.EventType.Trim(),
            x.Title, x.Message, x.MetadataJson ?? "{}");
        return Ok(new { success = true });
    }

    bool TryContext(out int storeId, out int userId)
    {
        storeId = int.TryParse(User.FindFirst("storeId")?.Value, out var s) ? s : 0;
        userId = int.TryParse(User.FindFirst("sub")?.Value, out var u) ? u : 0;
        return storeId > 0 && userId > 0;
    }

    bool HasAdminKey()
    {
        var expected = cfg["Admin:Key"] ?? string.Empty;
        var supplied = Request.Headers["X-Admin-Key"].ToString();
        if (expected.Length < 32 || supplied.Length != expected.Length) return false;
        return CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(supplied));
    }

    static void Add(DbCommand cmd, string name, object value)
    {
        var p = cmd.CreateParameter();
        p.ParameterName = name;
        p.Value = value;
        cmd.Parameters.Add(p);
    }

    static object SafeJson(string raw)
    {
        try { return JsonSerializer.Deserialize<JsonElement>(raw); }
        catch { return new Dictionary<string, object>(); }
    }

    static long ToUnixMillis(object value) => value switch
    {
        DateTimeOffset dto => dto.ToUnixTimeMilliseconds(),
        DateTime dt => new DateTimeOffset(DateTime.SpecifyKind(dt, DateTimeKind.Utc)).ToUnixTimeMilliseconds(),
        _ => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
    };

    static string DefaultTitle(string type) => type switch
    {
        "sale_created" => "فروش جدید ثبت شد",
        "receipt_printed" => "رسید چاپ شد",
        "invoice_printed" => "فاکتور چاپ شد",
        "sync_completed" => "همگام‌سازی انجام شد",
        "support_opened" => "پشتیبانی باز شد",
        _ => "اعلان Store Master"
    };
}

public sealed record ClientEventDto(string? EventType, string? Title, string? Message, string? EntityId, string? Platform, string? EventId = null);
public sealed record AdminNotificationDto(int? StoreId, string? EventType, string Title, string Message, string? MetadataJson);

using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Models;
using StoreMaster.Server.Services;

namespace StoreMaster.Server.Controllers;

[ApiController]
[AllowAnonymous]
[Route("api/v1/admin/support")]
public sealed class AdminSupportController : ControllerBase
{
    private readonly StoreMasterDbContext db;
    private readonly IConfiguration cfg;
    public AdminSupportController(StoreMasterDbContext db, IConfiguration cfg) { this.db = db; this.cfg = cfg; }

    bool HasKey()
    {
        var expected = cfg["Admin:Key"] ?? "";
        var supplied = Request.Headers["X-Admin-Key"].ToString();
        if (expected.Length < 32 || supplied.Length != expected.Length) return false;
        return CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(supplied));
    }

    [HttpGet("tickets")]
    public async Task<IActionResult> Tickets()
    {
        if (!HasKey()) return Unauthorized(new { message = "کلید مدیر معتبر نیست." });
        var rows = await db.SupportTickets.AsNoTracking().OrderByDescending(x => x.Id).Take(300)
            .Select(x => new { id = x.Id, ticketCode = x.TicketCode, type = x.Type, storeCode = x.StoreCode,
                licenseId = x.LicenseId, username = x.Username, contact = x.Contact, status = x.Status,
                message = x.Message, createdAt = x.CreatedAt })
            .ToListAsync();
        return Ok(new { items = rows });
    }

    [HttpGet("tickets/{ticketCode}/messages")]
    public async Task<IActionResult> Messages(string ticketCode, [FromQuery] long afterId = 0)
    {
        if (!HasKey()) return Unauthorized(new { message = "کلید مدیر معتبر نیست." });
        var ticket = await db.SupportTickets.AsNoTracking().FirstOrDefaultAsync(x => x.TicketCode == ticketCode);
        if (ticket == null) return NotFound(new { message = "تیکت پیدا نشد." });
        var rows = await db.SupportMessages.AsNoTracking().Where(x => x.TicketId == ticket.Id && x.Id > Math.Max(0, afterId))
            .OrderBy(x => x.Id).Take(500).Select(x => new { id = x.Id, senderRole = x.SenderRole,
                senderName = x.SenderName, message = x.Message, createdAt = x.CreatedAt }).ToListAsync();
        return Ok(new { ticketCode, status = ticket.Status, items = rows, lastId = rows.Count == 0 ? afterId : rows.Max(x => x.id) });
    }

    [HttpPost("tickets/{ticketCode}/messages")]
    public async Task<IActionResult> Reply(string ticketCode, [FromBody] AdminReplyDto? x)
    {
        if (!HasKey()) return Unauthorized(new { message = "کلید مدیر معتبر نیست." });
        if (x == null || string.IsNullOrWhiteSpace(x.Message) || x.Message.Trim().Length > 5000)
            return BadRequest(new { message = "پیام الزامی است و حداکثر ۵۰۰۰ نویسه دارد." });
        var ticket = await db.SupportTickets.FirstOrDefaultAsync(z => z.TicketCode == ticketCode);
        if (ticket == null) return NotFound(new { message = "تیکت پیدا نشد." });
        if (ticket.Status.Equals("CLOSED", StringComparison.OrdinalIgnoreCase)) return Conflict(new { message = "تیکت بسته شده است." });
        db.SupportMessages.Add(new SupportMessage { TicketId = ticket.Id, SenderRole = "ADMIN", SenderName = "پشتیبانی StoreMaster", Message = x.Message.Trim() });
        ticket.Status = "WAITING_CUSTOMER";
        await db.SaveChangesAsync();
        var storeId = await AppNotificationStore.FindStoreIdAsync(db, ticket.StoreCode, ticket.LicenseId);
        if (storeId.HasValue)
            await AppNotificationStore.PublishAsync(db, storeId.Value, "ticket_reply", "پاسخ جدید پشتیبانی",
                $"برای تیکت {ticket.TicketCode} پاسخ جدید ثبت شد.", "{}",
                $"ticket-reply:{ticket.TicketCode}:{ticket.Status}:{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}");
        return Ok(new { success = true });
    }

    [HttpPatch("tickets/{ticketCode}/status")]
    public async Task<IActionResult> Status(string ticketCode, [FromBody] AdminTicketStatusDto? x)
    {
        if (!HasKey()) return Unauthorized(new { message = "کلید مدیر معتبر نیست." });
        var status = x?.Status?.Trim().ToUpperInvariant() ?? "";
        if (status is not ("OPEN" or "WAITING_ADMIN" or "WAITING_CUSTOMER" or "CLOSED"))
            return BadRequest(new { message = "وضعیت انتخاب‌شده معتبر نیست." });
        var ticket = await db.SupportTickets.FirstOrDefaultAsync(z => z.TicketCode == ticketCode);
        if (ticket == null) return NotFound(new { message = "تیکت پیدا نشد." });
        ticket.Status = status;
        await db.SaveChangesAsync();
        var storeId = await AppNotificationStore.FindStoreIdAsync(db, ticket.StoreCode, ticket.LicenseId);
        if (storeId.HasValue)
            await AppNotificationStore.PublishAsync(db, storeId.Value,
                status == "CLOSED" ? "ticket_closed" : "ticket_status_changed",
                status == "CLOSED" ? "تیکت بسته شد" : "وضعیت تیکت تغییر کرد",
                $"وضعیت تیکت {ticket.TicketCode} به {status} تغییر کرد.", "{}",
                $"ticket-status:{ticket.TicketCode}:{status}:{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}");
        return Ok(new { success = true, status });
    }
}

public sealed record AdminReplyDto(string? Message);
public sealed record AdminTicketStatusDto(string? Status);

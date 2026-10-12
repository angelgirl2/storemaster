using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Models;
using System.Net.Http.Json;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("api/v1/support")]
public class SupportController : ControllerBase
{
    readonly StoreMasterDbContext db;
    readonly IConfiguration cfg;

    public SupportController(StoreMasterDbContext db, IConfiguration cfg)
    {
        this.db = db;
        this.cfg = cfg;
    }

    // A ticket-specific random capability lets an offline-first customer continue
    // a ticket thread without requiring SMS or exposing the store's full account token.
    [AllowAnonymous]
    [HttpPost("tickets")]
    public async Task<IActionResult> CreateTicket([FromBody] TicketDto? x)
    {
        if (x == null || string.IsNullOrWhiteSpace(x.Message) || x.Message.Trim().Length > 5000)
            return BadRequest(new { message = "متن درخواست الزامی است و باید حداکثر ۵۰۰۰ نویسه باشد." });

        var ticketCode = $"SMT-{RandomCode(12)}";
        var accessKey = CreateToken();
        var firstMessage = x.Message.Trim();
        var ticket = new SupportTicket
        {
            TicketCode = ticketCode,
            Type = string.IsNullOrWhiteSpace(x.Type) ? "SUPPORT" : x.Type.Trim().ToUpperInvariant()[..Math.Min(x.Type.Trim().Length, 40)],
            StoreCode = Clip(x.StoreCode, 100),
            LicenseId = Clip(x.LicenseId, 100),
            Username = string.IsNullOrWhiteSpace(x.Username) ? "کاربر" : Clip(x.Username, 100),
            DeviceId = Clip(x.DeviceId, 150),
            Contact = Clip(x.Contact, 150),
            Message = firstMessage,
            Status = "OPEN",
            AccessTokenHash = Hash(accessKey),
            CreatedAt = DateTime.UtcNow
        };

        db.SupportTickets.Add(ticket);
        await db.SaveChangesAsync();
        db.SupportMessages.Add(new SupportMessage
        {
            TicketId = ticket.Id, SenderRole = "CUSTOMER", SenderName = ticket.Username,
            Message = firstMessage, CreatedAt = ticket.CreatedAt
        });
        await db.SaveChangesAsync();

        var text = "🎫 تیکت جدید StoreMaster\n" +
                   $"کد تیکت: {ticket.TicketCode}\n" +
                   $"نوع: {ticket.Type}\n" +
                   $"کد فروشگاه: {ticket.StoreCode}\n" +
                   $"لایسنس: {ticket.LicenseId}\n" +
                   $"نام کاربری: {ticket.Username}\n\n" + ticket.Message;
        await SendTelegram(text);
        await SendBale(text);

        return Ok(new { success = true, ticketCode = ticket.TicketCode, accessKey, message = "تیکت ثبت شد؛ گفت‌وگو آماده است." });
    }

    [AllowAnonymous]
    [HttpGet("tickets/{ticketCode}/messages")]
    public async Task<IActionResult> CustomerMessages(string ticketCode, [FromQuery] long afterId = 0)
    {
        var ticket = await db.SupportTickets.FirstOrDefaultAsync(x => x.TicketCode == ticketCode);
        if (ticket == null) return NotFound(new { message = "تیکت پیدا نشد." });
        if (!ValidAccessKey(ticket, Request.Headers["X-Ticket-Access"].ToString())) return Unauthorized(new { message = "کلید دسترسی تیکت معتبر نیست." });
        var rows = await db.SupportMessages.AsNoTracking().Where(x => x.TicketId == ticket.Id && x.Id > Math.Max(0, afterId))
            .OrderBy(x => x.Id).Take(500)
            .Select(x => new { id = x.Id, senderRole = x.SenderRole, senderName = x.SenderName, message = x.Message, createdAt = x.CreatedAt })
            .ToListAsync();
        return Ok(new { ticketCode = ticket.TicketCode, status = ticket.Status, items = rows, lastId = rows.Count == 0 ? afterId : rows.Max(x => x.id) });
    }

    [AllowAnonymous]
    [HttpPost("tickets/{ticketCode}/messages")]
    public async Task<IActionResult> CustomerReply(string ticketCode, [FromBody] ChatMessageDto? x)
    {
        if (x == null || string.IsNullOrWhiteSpace(x.Message) || x.Message.Trim().Length > 5000)
            return BadRequest(new { message = "متن پیام الزامی است و حداکثر ۵۰۰۰ نویسه است." });
        var ticket = await db.SupportTickets.FirstOrDefaultAsync(z => z.TicketCode == ticketCode);
        if (ticket == null) return NotFound(new { message = "تیکت پیدا نشد." });
        if (!ValidAccessKey(ticket, Request.Headers["X-Ticket-Access"].ToString())) return Unauthorized(new { message = "کلید دسترسی تیکت معتبر نیست." });
        if (ticket.Status.Equals("CLOSED", StringComparison.OrdinalIgnoreCase)) return Conflict(new { message = "این تیکت بسته شده است." });
        var text = x.Message.Trim();
        db.SupportMessages.Add(new SupportMessage { TicketId = ticket.Id, SenderRole = "CUSTOMER", SenderName = ticket.Username, Message = text });
        ticket.Status = "WAITING_ADMIN";
        await db.SaveChangesAsync();
        await SendTelegram($"💬 پاسخ مشتری در تیکت {ticket.TicketCode}\n{text}");
        await SendBale($"💬 پاسخ مشتری در تیکت {ticket.TicketCode}\n{text}");
        return Ok(new { success = true });
    }

    // Backwards-compatible ticket history endpoint used by earlier client builds.
    [Authorize]
    [HttpGet("tickets")]
    public async Task<IActionResult> Tickets()
    {
        var storeCode = User.FindFirst("storeCode")?.Value;
        if (string.IsNullOrWhiteSpace(storeCode)) return Unauthorized();
        var rows = await db.SupportTickets.AsNoTracking().Where(x => x.StoreCode == storeCode)
            .OrderByDescending(x => x.Id).Take(200)
            .Select(x => new { x.TicketCode, x.Type, x.Status, x.Message, x.CreatedAt })
            .ToListAsync();
        return Ok(new { items = rows });
    }

    async Task SendTelegram(string text)
    {
        var token = cfg["Support:TelegramBotToken"];
        var chatId = cfg["Support:TelegramAdminChatId"];
        if (string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(chatId)) return;
        try { using var http = new HttpClient(); await http.PostAsJsonAsync($"https://api.telegram.org/bot{token}/sendMessage", new { chat_id = chatId, text }); }
        catch { /* message remains saved */ }
    }

    async Task SendBale(string text)
    {
        var token = cfg["Support:BaleBotToken"];
        var chatId = cfg["Support:BaleAdminChatId"];
        if (string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(chatId)) return;
        try { using var http = new HttpClient(); await http.PostAsJsonAsync($"https://tapi.bale.ai/bot{token}/sendMessage", new { chat_id = chatId, text }); }
        catch { /* message remains saved */ }
    }

    static bool ValidAccessKey(SupportTicket ticket, string supplied)
    {
        if (string.IsNullOrWhiteSpace(ticket.AccessTokenHash) || string.IsNullOrWhiteSpace(supplied)) return false;
        var expected = Convert.FromHexString(ticket.AccessTokenHash);
        var actual = Convert.FromHexString(Hash(supplied));
        return expected.Length == actual.Length && CryptographicOperations.FixedTimeEquals(expected, actual);
    }
    static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
    static string CreateToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    static string Clip(string? s, int max) { var v = (s ?? "").Trim(); return v.Length <= max ? v : v[..max]; }
    static string RandomCode(int length)
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var bytes = RandomNumberGenerator.GetBytes(length);
        return new string(bytes.Select(b => chars[b % chars.Length]).ToArray());
    }
}

public record TicketDto(string? Type, string? StoreCode, string? LicenseId, string? Username, string? DeviceId, string? Contact, string Message);
public record ChatMessageDto(string? Message);

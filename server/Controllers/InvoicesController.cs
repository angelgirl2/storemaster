using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Models;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("api/v1/invoices")]
public sealed class InvoicesController : ControllerBase
{
    private readonly StoreMasterDbContext db;
    private readonly IConfiguration cfg;
    public InvoicesController(StoreMasterDbContext db, IConfiguration cfg) { this.db = db; this.cfg = cfg; }

    [Authorize]
    [HttpPost("share")]
    public async Task<IActionResult> CreateShare([FromBody] CreateInvoiceShareDto? x)
    {
        if (x == null) return BadRequest(new { message = "اطلاعات فاکتور ارسال نشده است." });
        if (!int.TryParse(User.FindFirst("storeId")?.Value, out var storeId) || storeId <= 0)
            return Unauthorized(new { message = "نشست فروشگاه معتبر نیست؛ ابتدا آنلاین وارد شوید." });
        if (x.Items == null || x.Items.Count == 0 || x.Items.Count > 300)
            return BadRequest(new { message = "فاکتور باید بین ۱ تا ۳۰۰ ردیف کالا داشته باشد." });
        if (x.FinalAmount < 0 || x.TotalAmount < 0 || x.Discount < 0 || x.PaidAmount < 0 || x.DebtAmount < 0)
            return BadRequest(new { message = "مبالغ فاکتور نمی‌توانند منفی باشند." });
        if (x.Items.Any(i => string.IsNullOrWhiteSpace(i.Name) || i.Name.Trim().Length > 200 || i.Quantity <= 0 || i.UnitPrice < 0))
            return BadRequest(new { message = "یکی از ردیف‌های فاکتور معتبر نیست." });

        var store = await db.Stores.AsNoTracking().FirstOrDefaultAsync(s => s.Id == storeId && s.Active);
        if (store == null) return Unauthorized(new { message = "فروشگاه غیرفعال است." });
        var license = await db.Licenses.AsNoTracking().Where(l => l.StoreId == storeId)
            .OrderByDescending(l => l.ExpiresAt).FirstOrDefaultAsync();
        if (license == null || license.Status != "ACTIVE" || license.ExpiresAt <= DateTime.UtcNow)
            return StatusCode(403, new { message = "برای اشتراک‌گذاری آنلاین فاکتور، لایسنس فروشگاه باید فعال باشد." });

        var token = CreateToken();
        var share = new InvoiceShare
        {
            Token = token, StoreId = store.Id, StoreName = store.Name,
            StorePhone = Clip(x.StorePhone, 50), InvoiceNumber = Clip(x.InvoiceNumber, 100),
            DateText = Clip(x.DateText, 100), CustomerName = Clip(x.CustomerName, 150),
            Currency = Clip(x.Currency, 20) is { Length: > 0 } currency ? currency : store.Currency,
            ItemsJson = JsonSerializer.Serialize(x.Items), TotalAmount = x.TotalAmount,
            Discount = x.Discount, FinalAmount = x.FinalAmount, PaidAmount = x.PaidAmount,
            DebtAmount = x.DebtAmount, CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30)
        };
        db.InvoiceShares.Add(share);
        await db.SaveChangesAsync();
        var configuredBase = cfg["Public:BaseUrl"]?.Trim().TrimEnd('/');
        var baseUrl = string.IsNullOrWhiteSpace(configuredBase) ? $"{Request.Scheme}://{Request.Host}" : configuredBase;
        return Ok(new { success = true, token, url = $"{baseUrl}/api/v1/invoices/public/{token}", expiresAt = share.ExpiresAt });
    }

    [AllowAnonymous]
    [HttpGet("public/{token}")]
    public async Task<IActionResult> PublicInvoice(string token)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Length > 100) return NotFound();
        var share = await db.InvoiceShares.AsNoTracking().FirstOrDefaultAsync(s => s.Token == token);
        if (share == null || share.ExpiresAt <= DateTime.UtcNow)
            return Content("<!doctype html><html lang=\"fa\" dir=\"rtl\"><meta charset=\"utf-8\"><title>فاکتور در دسترس نیست</title><body style=\"font-family:Tahoma;padding:32px;text-align:center\"><h2>این لینک فاکتور منقضی شده یا معتبر نیست.</h2></body></html>", "text/html; charset=utf-8", System.Text.Encoding.UTF8, 404);

        var enc = HtmlEncoder.Default;
        var items = JsonSerializer.Deserialize<List<InvoiceShareItemDto>>(share.ItemsJson) ?? new();
        var fa = CultureInfo.GetCultureInfo("fa-IR");
        string n(decimal v) => v.ToString("N0", fa);
        var rows = string.Join("", items.Select((i, index) => $"<tr><td>{index + 1}</td><td>{enc.Encode(i.Name)}</td><td>{n(i.Quantity)}</td><td>{n(i.UnitPrice)} {enc.Encode(share.Currency)}</td><td>{n(i.Quantity * i.UnitPrice)} {enc.Encode(share.Currency)}</td></tr>"));
        var html = $"""<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>فاکتور {enc.Encode(share.InvoiceNumber)}</title><style>*{{box-sizing:border-box}}body{{font-family:Tahoma,'Segoe UI',sans-serif;background:#f5f7fb;color:#1f2937;margin:0;padding:24px}}main{{max-width:900px;margin:auto;background:#fff;border:1px solid #e2e8f0;border-radius:18px;overflow:hidden;box-shadow:0 10px 40px #0f172a12}}header{{background:linear-gradient(120deg,#26378d,#5c6bc0);color:#fff;padding:24px}}h1{{font-size:24px;margin:0 0 8px}}.meta{{display:flex;gap:12px;flex-wrap:wrap;font-size:13px;opacity:.95}}section{{padding:20px}}.party{{display:flex;justify-content:space-between;gap:15px;flex-wrap:wrap;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:14px;margin-bottom:18px}}table{{width:100%;border-collapse:collapse;font-size:13px}}th{{background:#eef2ff;color:#27378c;text-align:right;padding:12px}}td{{padding:11px;border-bottom:1px solid #edf0f5}}tbody tr:nth-child(even){{background:#fafbff}}.totals{{max-width:400px;margin:20px 0 0 auto;padding:14px 16px;border:1px solid #e2e8f0;border-radius:12px}}.line{{display:flex;justify-content:space-between;padding:7px 0;border-bottom:1px dashed #e2e8f0}}.line:last-child{{font-weight:bold;font-size:17px;border:0;color:#27378c}}footer{{padding:16px;text-align:center;color:#64748b;font-size:12px;border-top:1px solid #eef2f7}}@media(max-width:600px){{body{{padding:8px}}header,section{{padding:14px}}table{{font-size:11px}}th,td{{padding:7px 5px}}h1{{font-size:19px}}}}@media print{{body{{background:#fff;padding:0}}main{{box-shadow:none;border:0}}header{{print-color-adjust:exact;-webkit-print-color-adjust:exact}}}}</style></head><body><main><header><h1>{enc.Encode(share.StoreName)}</h1><div class="meta"><span>فاکتور شماره: {enc.Encode(share.InvoiceNumber)}</span><span>تاریخ: {enc.Encode(share.DateText)}</span></div></header><section><div class="party"><span><b>مشتری:</b> {enc.Encode(string.IsNullOrWhiteSpace(share.CustomerName) ? "مشتری حضوری" : share.CustomerName)}</span><span><b>تلفن فروشگاه:</b> {enc.Encode(share.StorePhone)}</span></div><table><thead><tr><th>ردیف</th><th>کالا / خدمت</th><th>تعداد</th><th>قیمت واحد</th><th>مبلغ کل</th></tr></thead><tbody>{rows}</tbody></table><div class="totals"><div class="line"><span>جمع کل</span><span>{n(share.TotalAmount)} {enc.Encode(share.Currency)}</span></div><div class="line"><span>تخفیف</span><span>{n(share.Discount)} {enc.Encode(share.Currency)}</span></div><div class="line"><span>مبلغ نهایی</span><span>{n(share.FinalAmount)} {enc.Encode(share.Currency)}</span></div><div class="line"><span>پرداختی</span><span>{n(share.PaidAmount)} {enc.Encode(share.Currency)}</span></div><div class="line"><span>مانده</span><span>{n(share.DebtAmount)} {enc.Encode(share.Currency)}</span></div></div></section><footer>این لینک امن است و تا {enc.Encode(share.ExpiresAt.ToString("yyyy-MM-dd"))} اعتبار دارد. با تشکر از خرید شما.</footer></main></body></html>""";
        return Content(html, "text/html; charset=utf-8");
    }

    static string CreateToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    static string Clip(string? value, int max) { var s = (value ?? "").Trim(); return s.Length <= max ? s : s[..max]; }
}

public sealed record CreateInvoiceShareDto(
    string? InvoiceNumber, string? DateText, string? CustomerName, string? Currency,
    List<InvoiceShareItemDto>? Items, decimal TotalAmount, decimal Discount,
    decimal FinalAmount, decimal PaidAmount, decimal DebtAmount, string? StorePhone = null);
public sealed record InvoiceShareItemDto(string Name, decimal Quantity, decimal UnitPrice, decimal? LineTotal = null);

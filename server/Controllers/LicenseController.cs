using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using System.Text.Json;
using BCrypt.Net;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("api/v1/licenses")]
public class LicenseController : ControllerBase
{
    readonly StoreMasterDbContext db;

    public LicenseController(StoreMasterDbContext db) => this.db = db;

    [AllowAnonymous]
    [HttpPost("activate")]
    public async Task<IActionResult> Activate(ActivateDto x)
    {
        if (string.IsNullOrWhiteSpace(x.LicenseId) || string.IsNullOrWhiteSpace(x.DeviceId))
            return BadRequest(new { message = "LicenseId و DeviceId الزامی هستند." });
        var l = await db.Licenses.FirstOrDefaultAsync(z => z.LicenseId == x.LicenseId);
        if (l == null)
            return NotFound(new { message = "لایسنس پیدا نشد" });

        var linked = await db.UserDevices.AnyAsync(
            z => z.StoreId == l.StoreId &&
                 z.DeviceId == x.DeviceId &&
                 z.Active);

        if (!linked)
            return Unauthorized(new { message = "دستگاه با لایسنس ثبت نشده است" });

        var active =
            l.Status == "ACTIVE" &&
            l.ExpiresAt > DateTime.UtcNow;

        return Ok(BuildActivationResponse(l, active));
    }

    [AllowAnonymous]
    [HttpPost("activate-code")]
    public async Task<IActionResult> ActivateCode(ActivationCodeDto x)
    {
        if (string.IsNullOrWhiteSpace(x.Code) || string.IsNullOrWhiteSpace(x.DeviceId))
            return BadRequest(new { message = "کد فعال‌سازی و DeviceId الزامی هستند." });
        var code = x.Code.Trim().ToUpperInvariant();

        var l = await db.Licenses
            .FirstOrDefaultAsync(
                z => z.ActivationCode == code ||
                     z.LicenseId == code);

        if (l == null)
            return NotFound(new { message = "کد فعال‌سازی پیدا نشد." });

        if (l.Status != "ACTIVE")
            return StatusCode(403, new { message = $"وضعیت لایسنس {l.Status} است." });

        if (l.ExpiresAt <= DateTime.UtcNow)
            return StatusCode(403, new { message = "اعتبار لایسنس به پایان رسیده است." });

        var device = await db.UserDevices
            .FirstOrDefaultAsync(
                z => z.StoreId == l.StoreId &&
                     z.DeviceId == x.DeviceId &&
                     z.Active);

        if (device == null)
            return Unauthorized(new { message = "این Device ID برای این لایسنس ثبت نشده است." });

        var user = await db.Users.FindAsync(device.UserId);
        var store = await db.Stores.FindAsync(l.StoreId);
        if (user == null || store == null)
            return NotFound(new { message = "اطلاعات فروشگاه کامل نیست." });

        // One-time online activation: after the first successful use,
        // the activation code is consumed and cannot be reused.
        if (l.ActivationCodeUsed)
            return Conflict(new { message = "این کد فعال‌سازی قبلاً استفاده شده است. برای بازیابی رمز از پشتیبانی تیکت ثبت کنید." });

        var password = string.IsNullOrWhiteSpace(l.InitialPassword)
            ? CreatePassword()
            : l.InitialPassword;

        user.Username = string.IsNullOrWhiteSpace(l.Username) ? "admin" : l.Username;
        user.PinHash = BCrypt.Net.BCrypt.HashPassword(password);
        user.Active = true;
        l.ActivationCodeUsed = true;

        await db.SaveChangesAsync();

        var perms = await GetPermissions(l.StoreId, user.Id);
        var features = JsonSerializer.Deserialize<List<string>>(l.FeaturesJson) ?? new();
        var businesses = JsonSerializer.Deserialize<List<string>>(l.BusinessTypesJson) ?? new();

        return Ok(new
        {
            valid = true,
            activationMode = "ONLINE",
            storeCode = l.LicenseId,
            username = user.Username,
            password,
            recoveryCode = l.RecoveryCode,
            userId = user.Id,
            storeId = store.Id,
            storeName = store.Name,
            storeType = store.Type,
            businessTitle = store.BusinessTitle,
            currency = store.Currency,
            licenseId = l.LicenseId,
            licensePlan = l.Plan,
            licenseStatus = l.Status,
            licenseExpiresAt = new DateTimeOffset(l.ExpiresAt).ToUnixTimeMilliseconds(),
            features,
            businessTypes = businesses,
            permissions = perms
        });
    }

    [AllowAnonymous]
    [HttpGet("pricing")]
    public async Task<IActionResult> Pricing()
    {
        var rows = await db.PricingEntries
            .AsNoTracking()
            .OrderBy(x => x.PlanDays)
            .ToListAsync();

        if (rows.Count == 0)
        {
            rows = new List<StoreMaster.Server.Models.PricingEntry>
            {
                new() { PlanDays = 30, Price = 990000, Currency = "تومان" },
                new() { PlanDays = 90, Price = 2490000, Currency = "تومان" },
                new() { PlanDays = 180, Price = 4490000, Currency = "تومان" },
                new() { PlanDays = 365, Price = 7990000, Currency = "تومان" },
            };
        }

        return Ok(new
        {
            version = rows.Max(x => new DateTimeOffset(x.UpdatedAt).ToUnixTimeMilliseconds()),
            currency = rows.FirstOrDefault()?.Currency ?? "تومان",
            prices = rows.ToDictionary(x => x.PlanDays.ToString(), x => x.Price)
        });
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        if (!TryContext(out var sid))
            return Unauthorized();

        var l = await db.Licenses
            .Where(x => x.StoreId == sid)
            .OrderByDescending(x => x.ExpiresAt)
            .FirstOrDefaultAsync();

        if (l == null)
            return NotFound(new { message = "لایسنس پیدا نشد" });

        return Ok(BuildActivationResponse(
            l,
            l.ExpiresAt > DateTime.UtcNow &&
            l.Status == "ACTIVE"));
    }

    static object BuildActivationResponse(
        StoreMaster.Server.Models.License l,
        bool active)
    {
        return new
        {
            valid = active,
            status = active ? "ACTIVE" : (l.Status != "ACTIVE" ? l.Status : "EXPIRED"),
            activationMode = "ONLINE",
            storeCode = l.LicenseId,
            username = l.Username,
            recoveryCode = l.RecoveryCode,
            licenseId = l.LicenseId,
            licensePlan = l.Plan,
            licenseExpiresAt = new DateTimeOffset(l.ExpiresAt).ToUnixTimeMilliseconds(),
            serverTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            features = JsonSerializer.Deserialize<List<string>>(l.FeaturesJson) ?? new(),
            businessTypes = JsonSerializer.Deserialize<List<string>>(l.BusinessTypesJson) ?? new()
        };
    }

    async Task<List<string>> GetPermissions(int storeId, int userId)
    {
        var su = await db.StoreUsers
            .FirstOrDefaultAsync(
                z => z.StoreId == storeId &&
                     z.UserId == userId &&
                     z.Active);

        return su == null
            ? new List<string>()
            : JsonSerializer.Deserialize<List<string>>(su.PermissionsJson) ?? new List<string>();
    }

    bool TryContext(out int sid)
    {
        sid = int.TryParse(
            User.FindFirst("storeId")?.Value,
            out var s)
            ? s
            : 0;

        return sid > 0;
    }

    static string CreatePassword()
    {
        const string chars =
            "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
        var rng = Random.Shared;
        return new string(
            Enumerable.Range(0, 10)
                .Select(_ => chars[rng.Next(chars.Length)])
                .ToArray());
    }
}

public record ActivateDto(string LicenseId, string DeviceId);
public record ActivationCodeDto(string Code, string DeviceId);

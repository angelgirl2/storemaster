using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Models;
using StoreMaster.Server.Services;
using System.Text.Json;
using System.Security.Cryptography;
using System.Text;
using BCrypt.Net;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("api/v1/admin")]
public class AdminController : ControllerBase
{
    readonly StoreMasterDbContext db;
    readonly IConfiguration cfg;

    public AdminController(StoreMasterDbContext db, IConfiguration cfg)
    {
        this.db = db;
        this.cfg = cfg;
    }

    bool OkKey(HttpRequest r)
    {
        var expected = cfg["Admin:Key"] ?? string.Empty;
        var supplied = r.Headers["X-Admin-Key"].ToString();
        if (expected.Length < 32 || supplied.Length != expected.Length) return false;
        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(supplied));
    }

    [HttpGet("trial-policy")]
    public async Task<IActionResult> GetTrialPolicy()
    {
        if (!OkKey(Request)) return Unauthorized();
        var policy = await db.TrialPolicies.FirstOrDefaultAsync(x => x.Id == 1);
        if (policy == null)
        {
            policy = new TrialPolicy();
            db.TrialPolicies.Add(policy);
            await db.SaveChangesAsync();
        }
        return Ok(new
        {
            durationDays = 15,
            features = JsonSerializer.Deserialize<List<string>>(policy.FeaturesJson) ?? new List<string>(),
            businessTypes = JsonSerializer.Deserialize<List<string>>(policy.BusinessTypesJson) ?? new List<string> { "*" },
            updatedAt = policy.UpdatedAt
        });
    }

    [HttpPut("trial-policy")]
    public async Task<IActionResult> UpdateTrialPolicy([FromBody] TrialPolicyDto? x)
    {
        if (!OkKey(Request)) return Unauthorized();
        if (x == null || x.Features == null || x.Features.Count == 0 || x.BusinessTypes == null || x.BusinessTypes.Count == 0)
            return BadRequest(new { message = "حداقل یک قابلیت و یک نوع کسب‌وکار برای تریال انتخاب کنید." });
        var knownFeatures = new HashSet<string>(new[] { "sales", "products", "inventory", "customers", "accounting", "reports", "business_modules", "attendance", "multi_warehouse", "sms", "advanced_reports" }, StringComparer.OrdinalIgnoreCase);
        var features = x.Features.Select(v => (v ?? "").Trim().ToLowerInvariant()).Distinct().ToList();
        if (features.Any(v => !knownFeatures.Contains(v)))
            return BadRequest(new { message = "فهرست قابلیت‌های تریال شامل کد نامعتبر است." });
        var businesses = x.BusinessTypes.Select(v => (v ?? "").Trim().ToUpperInvariant()).Where(v => v.Length > 0).Distinct().ToList();
        if (businesses.Contains("*") && businesses.Count > 1)
            return BadRequest(new { message = "برای همه مشاغل، '*' را به‌تنهایی انتخاب کنید." });
        if (businesses.Any(v => v != "*" && !System.Text.RegularExpressions.Regex.IsMatch(v, "^[A-Z][A-Z0-9_]{1,49}$")))
            return BadRequest(new { message = "کد نوع کسب‌وکار معتبر نیست." });
        var policy = await db.TrialPolicies.FirstOrDefaultAsync(v => v.Id == 1);
        if (policy == null) { policy = new TrialPolicy(); db.TrialPolicies.Add(policy); }
        policy.FeaturesJson = JsonSerializer.Serialize(features);
        policy.BusinessTypesJson = JsonSerializer.Serialize(businesses);
        policy.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return Ok(new { success = true, durationDays = 15, features, businessTypes = businesses, updatedAt = policy.UpdatedAt });
    }

    [HttpGet("stores")]
    public async Task<IActionResult> Stores()
    {
        if (!OkKey(Request)) return Unauthorized();
        return Ok(new { items = await db.Stores.AsNoTracking().ToListAsync() });
    }


    [HttpPost("stores/provision")]
    public async Task<IActionResult> ProvisionStore(ProvisionStoreDto x)
    {
        if (!OkKey(Request)) return Unauthorized();
        if (string.IsNullOrWhiteSpace(x.StoreName)) return BadRequest(new { message = "نام فروشگاه الزامی است." });
        if (string.IsNullOrWhiteSpace(x.AdminPin) || x.AdminPin.Trim().Length < 4) return BadRequest(new { message = "PIN مدیر حداقل 4 کاراکتر است." });
        if (x.DurationDays <= 0) return BadRequest(new { message = "مدت لایسنس نامعتبر است." });

        await using var tx = await db.Database.BeginTransactionAsync();
        try
        {
            var store = new Store
            {
                Code = $"SM-{Guid.NewGuid():N}"[..14].ToUpperInvariant(),
                Name = x.StoreName.Trim(),
                Type = x.StoreType?.Trim() ?? "RETAIL",
                BusinessTitle = x.BusinessTitle?.Trim() ?? x.StoreName.Trim(),
                Currency = string.IsNullOrWhiteSpace(x.Currency) ? "IRR" : x.Currency.Trim(),
                Active = true
            };
            db.Stores.Add(store);
            await db.SaveChangesAsync();

            var username = string.IsNullOrWhiteSpace(x.Username) ? "admin" : x.Username.Trim();
            var user = new User
            {
                Username = username,
                Name = string.IsNullOrWhiteSpace(x.AdminName) ? "مدیر" : x.AdminName.Trim(),
                Phone = x.Phone?.Trim() ?? "",
                PinHash = BCrypt.Net.BCrypt.HashPassword(x.AdminPin.Trim()),
                Active = true
            };
            db.Users.Add(user);
            await db.SaveChangesAsync();

            db.StoreUsers.Add(new StoreUser
            {
                StoreId = store.Id,
                UserId = user.Id,
                Role = "OWNER",
                PermissionsJson = JsonSerializer.Serialize(Services.PermissionService.Defaults("OWNER")),
                Active = true
            });

            db.UserDevices.Add(new UserDevice
            {
                StoreId = store.Id, UserId = user.Id, DeviceId = x.DeviceId ?? "",
                Platform = x.Platform ?? "", Name = x.DeviceName ?? "", Active = true
            });

            var lic = new License
            {
                StoreId = store.Id,
                LicenseId = $"LIC-{Guid.NewGuid():N}"[..20].ToUpperInvariant(),
                ActivationCode = CreateReadableCode(18),
                Plan = string.IsNullOrWhiteSpace(x.Plan) ? "TRIAL" : x.Plan.Trim().ToUpperInvariant(),
                Status = "ACTIVE",
                IssuedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddDays(x.DurationDays),
                OriginalPrice = Math.Max(0, x.OriginalPrice),
                FinalPrice = Math.Max(0, x.FinalPrice),
                FeaturesJson = JsonSerializer.Serialize(x.Features ?? new List<string>()),
                BusinessTypesJson = JsonSerializer.Serialize(x.BusinessTypes ?? new List<string> { store.Type }),
                MaxUsers = Math.Max(1, x.MaxUsers),
                Username = username
            };
            db.Licenses.Add(lic);
            await db.SaveChangesAsync();
            await tx.CommitAsync();

            return Ok(new
            {
                success = true, storeId = store.Id, storeCode = store.Code, userId = user.Id,
                username, password = x.AdminPin.Trim(), licenseId = lic.LicenseId,
                activationCode = lic.ActivationCode, expiresAt = new DateTimeOffset(lic.ExpiresAt).ToUnixTimeMilliseconds()
            });
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }

    [HttpGet("roles")]
    public IActionResult Roles()
    {
        if (!OkKey(Request)) return Unauthorized();
        return Ok(new
        {
            roles = new[] { "OWNER", "ADMIN", "MANAGER", "SELLER", "WAREHOUSE", "ACCOUNTANT", "CASHIER", "CUSTOM" },
            permissions = Services.PermissionService.Defaults("OWNER")
        });
    }

    [HttpPost("licenses")]
    public async Task<IActionResult> CreateLicense(LicenseDto x)
    {
        if (!OkKey(Request)) return Unauthorized();
        if (string.IsNullOrWhiteSpace(x.StoreCode)) return BadRequest(new { message = "کد فروشگاه الزامی است." });
        if (x.DurationDays <= 0) return BadRequest(new { message = "مدت لایسنس باید بیشتر از صفر باشد." });
        if (x.MaxUsers <= 0) return BadRequest(new { message = "حداکثر کاربران باید بیشتر از صفر باشد." });
        var store = await db.Stores.FirstOrDefaultAsync(s => s.Code == x.StoreCode);
        if (store == null) return NotFound(new { message = "فروشگاه پیدا نشد" });

        var now = DateTime.UtcNow;
        var licenseId = string.IsNullOrWhiteSpace(x.LicenseId)
            ? $"LIC-{Guid.NewGuid():N}"[..20].ToUpperInvariant()
            : x.LicenseId.Trim();

        var codeConflict = await db.Licenses.AnyAsync(z => z.LicenseId == licenseId);
        if (codeConflict) return Conflict(new { message = "شناسه لایسنس تکراری است." });

        var activationCode = string.IsNullOrWhiteSpace(x.ActivationCode)
            ? CreateReadableCode(18)
            : x.ActivationCode.Trim();

        if (await db.Licenses.AnyAsync(z => z.ActivationCode == activationCode))
            return Conflict(new { message = "کد فعال‌سازی تکراری است." });

        var lic = new License
        {
            StoreId = store.Id,
            LicenseId = licenseId,
            ActivationCode = activationCode,
            Plan = x.Plan,
            Status = "ACTIVE",
            IssuedAt = now,
            ExpiresAt = now.AddDays(x.DurationDays),
            OriginalPrice = x.OriginalPrice,
            FinalPrice = x.FinalPrice,
            DiscountCode = x.DiscountCode ?? "",
            FeaturesJson = JsonSerializer.Serialize(x.Features ?? new()),
            BusinessTypesJson = JsonSerializer.Serialize(x.BusinessTypes ?? new() { "*" }),
            MaxUsers = x.MaxUsers,
            Username = string.IsNullOrWhiteSpace(x.Username) ? "admin" : x.Username.Trim(),
            InitialPassword = x.Password ?? "",
            RecoveryCode = x.RecoveryCode ?? ""
        };

        db.Licenses.Add(lic);
        await db.SaveChangesAsync();

        return Ok(new
        {
            licenseId = lic.LicenseId,
            storeCode = store.Code,
            activationCode = lic.ActivationCode,
            username = lic.Username,
            expiresAt = new DateTimeOffset(lic.ExpiresAt).ToUnixTimeMilliseconds()
        });
    }

    [HttpPost("licenses/by-device")]
    public async Task<IActionResult> CreateByDevice(LicenseDtoByDevice x)
    {
        if (!OkKey(Request)) return Unauthorized();
        if (string.IsNullOrWhiteSpace(x.DeviceId)) return BadRequest(new { message = "DeviceId الزامی است." });
        if (x.MaxUsers <= 0) return BadRequest(new { message = "حداکثر کاربران باید بیشتر از صفر باشد." });

        var now = DateTime.UtcNow;
        if (string.Equals(x.Plan, "TRIAL", StringComparison.OrdinalIgnoreCase))
        {
            var policy = await db.TrialPolicies.FirstOrDefaultAsync(t => t.Id == 1);
            if (policy == null)
            {
                policy = new TrialPolicy();
                db.TrialPolicies.Add(policy);
                await db.SaveChangesAsync();
            }

            var permittedFeatures = JsonSerializer.Deserialize<List<string>>(policy.FeaturesJson) ?? new List<string>();
            var permittedBusinesses = JsonSerializer.Deserialize<List<string>>(policy.BusinessTypesJson) ?? new List<string> { "*" };
            var requestedBusiness = (x.StoreType ?? x.BusinessTypes?.FirstOrDefault() ?? "GENERAL").Trim().ToUpperInvariant();
            if (string.IsNullOrWhiteSpace(requestedBusiness))
                return BadRequest(new { message = "نوع کسب‌وکار برای Trial الزامی است." });
            if (permittedFeatures.Count == 0)
                return StatusCode(503, new { message = "سیاست دسترسی Trial توسط مدیر تنظیم نشده است." });
            if (!permittedBusinesses.Contains("*") && !permittedBusinesses.Contains(requestedBusiness))
                return StatusCode(403, new { message = "سیاست مرکزی مدیر اجازه Trial برای این نوع کسب‌وکار را نمی‌دهد." });

            var selectedFeatures = (x.Features ?? new List<string>()).Select(v => v.Trim().ToLowerInvariant()).Distinct().ToList();
            var finalFeatures = selectedFeatures.Count == 0
                ? permittedFeatures
                : permittedFeatures.Where(v => selectedFeatures.Contains(v, StringComparer.OrdinalIgnoreCase)).ToList();
            if (finalFeatures.Count == 0)
                return StatusCode(403, new { message = "قابلیت‌های انتخابی با سیاست مرکزی Trial هم‌پوشانی ندارند." });

            x = x with
            {
                Plan = "TRIAL",
                StoreType = requestedBusiness,
                ExpiresAt = new DateTimeOffset(now.AddDays(15)).ToUnixTimeMilliseconds(),
                OriginalPrice = 0,
                FinalPrice = 0,
                DiscountCode = null,
                Features = finalFeatures,
                BusinessTypes = new List<string> { requestedBusiness }
            };
        }

        var device = await db.UserDevices.FirstOrDefaultAsync(z => z.DeviceId == x.DeviceId && z.Active);
        Store store;
        User user;

        if (device == null)
        {
            if (string.IsNullOrWhiteSpace(x.LicenseId))
                return BadRequest(new { message = "LicenseId برای ساخت فروشگاه الزامی است." });

            if (await db.Stores.AnyAsync(s => s.Code == x.LicenseId.Trim()))
                return Conflict(new { message = "کد فروشگاه/لایسنس تکراری است." });

            store = new Store
            {
                Code = x.LicenseId.Trim(),
                Name = string.IsNullOrWhiteSpace(x.StoreName) ? "فروشگاه" : x.StoreName.Trim(),
                Type = string.IsNullOrWhiteSpace(x.StoreType) ? "GENERAL" : x.StoreType.Trim(),
                BusinessTitle = string.IsNullOrWhiteSpace(x.BusinessTitle) ? "فروشگاه" : x.BusinessTitle.Trim(),
                Currency = string.IsNullOrWhiteSpace(x.Currency) ? "تومان" : x.Currency.Trim()
            };
            db.Stores.Add(store);
            await db.SaveChangesAsync();

            user = new User
            {
                Username = string.IsNullOrWhiteSpace(x.Username) ? "admin" : x.Username.Trim(),
                Name = string.IsNullOrWhiteSpace(x.CustomerName) ? "مدیر فروشگاه" : x.CustomerName.Trim(),
                Phone = x.Phone ?? "",
                PinHash = BCrypt.Net.BCrypt.HashPassword(string.IsNullOrWhiteSpace(x.Password) ? CreatePassword() : x.Password!)
            };
            db.Users.Add(user);
            await db.SaveChangesAsync();

            var perms = Services.PermissionService.Defaults("OWNER");
            db.StoreUsers.Add(new StoreUser
            {
                StoreId = store.Id,
                UserId = user.Id,
                Role = "OWNER",
                PermissionsJson = JsonSerializer.Serialize(perms)
            });

            device = new UserDevice
            {
                StoreId = store.Id,
                UserId = user.Id,
                DeviceId = x.DeviceId.Trim(),
                Platform = x.Platform ?? "",
                Name = x.DeviceName ?? ""
            };
            db.UserDevices.Add(device);
            await db.SaveChangesAsync();
        }
        else
        {
            store = await db.Stores.FindAsync(device.StoreId)
                    ?? throw new InvalidOperationException("فروشگاه دستگاه پیدا نشد.");

            user = await db.Users.FindAsync(device.UserId)
                   ?? throw new InvalidOperationException("کاربر دستگاه پیدا نشد.");

            if (!string.IsNullOrWhiteSpace(x.LicenseId) &&
                !string.Equals(store.Code, x.LicenseId.Trim(), StringComparison.Ordinal))
            {
                if (await db.Stores.AnyAsync(s => s.Code == x.LicenseId.Trim() && s.Id != store.Id))
                    return Conflict(new { message = "کد فروشگاه جدید قبلاً استفاده شده است." });

                store.Code = x.LicenseId.Trim();
            }

            if (!string.IsNullOrWhiteSpace(x.Username))
                user.Username = x.Username.Trim();

            if (!string.IsNullOrWhiteSpace(x.Password))
                user.PinHash = BCrypt.Net.BCrypt.HashPassword(x.Password);

            if (!string.IsNullOrWhiteSpace(x.CustomerName))
                user.Name = x.CustomerName.Trim();

            if (!string.IsNullOrWhiteSpace(x.Phone))
                user.Phone = x.Phone.Trim();

            device.Active = true;
            device.Platform = x.Platform ?? device.Platform;
            device.Name = x.DeviceName ?? device.Name;
        }

        var existing = string.IsNullOrWhiteSpace(x.LicenseId)
            ? null
            : await db.Licenses.FirstOrDefaultAsync(z => z.LicenseId == x.LicenseId.Trim());

        if (existing != null)
        {
            // A retry for the same license ID may happen after a network timeout.
            // Reapply the operator-generated PIN so returned credentials stay valid.
            if (!string.IsNullOrWhiteSpace(x.Password))
            {
                user.PinHash = BCrypt.Net.BCrypt.HashPassword(x.Password);
                existing.InitialPassword = x.Password;
            }
            if (string.Equals(existing.Plan, "TRIAL", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(x.Plan, "TRIAL", StringComparison.OrdinalIgnoreCase))
            {
                existing.Status = "ACTIVE";
                existing.Plan = x.Plan;
                existing.IssuedAt = now;
                existing.ExpiresAt = DateTimeOffset.FromUnixTimeMilliseconds(x.ExpiresAt).UtcDateTime;
                existing.OriginalPrice = x.OriginalPrice;
                existing.FinalPrice = x.FinalPrice;
                existing.DiscountCode = x.DiscountCode?.Trim().ToUpperInvariant() ?? "";
                existing.FeaturesJson = JsonSerializer.Serialize(x.Features ?? new());
                existing.BusinessTypesJson = JsonSerializer.Serialize(x.BusinessTypes ?? new() { "*" });
                existing.MaxUsers = Math.Max(1, x.MaxUsers);
                existing.ActivationCodeUsed = false;
                if (!string.IsNullOrWhiteSpace(x.ActivationCode) && x.ActivationCode.Trim() != existing.ActivationCode)
                {
                    if (await db.Licenses.AnyAsync(z => z.ActivationCode == x.ActivationCode.Trim() && z.Id != existing.Id))
                        return Conflict(new { message = "کد فعال‌سازی تکراری است." });
                    existing.ActivationCode = x.ActivationCode.Trim();
                }
                await db.SaveChangesAsync();
                return Ok(new
                {
                    licenseId = existing.LicenseId,
                    storeId = existing.StoreId,
                    userId = user.Id,
                    storeCode = store.Code,
                    activationCode = existing.ActivationCode,
                    username = existing.Username,
                    expiresAt = new DateTimeOffset(existing.ExpiresAt).ToUnixTimeMilliseconds(),
                    originalPrice = existing.OriginalPrice,
                    finalPrice = existing.FinalPrice,
                    discountCode = existing.DiscountCode
                });
            }

            return Ok(new
            {
                licenseId = existing.LicenseId,
                storeId = existing.StoreId,
                userId = user.Id,
                storeCode = store.Code,
                activationCode = existing.ActivationCode,
                username = existing.Username,
                expiresAt = new DateTimeOffset(existing.ExpiresAt).ToUnixTimeMilliseconds(),
                originalPrice = existing.OriginalPrice,
                finalPrice = existing.FinalPrice,
                discountCode = existing.DiscountCode
            });
        }

        var final = x.FinalPrice;
        var originalPrice = x.OriginalPrice;
        var code = x.DiscountCode?.Trim().ToUpperInvariant() ?? "";

        if (string.Equals(x.Plan, "TRIAL", StringComparison.OrdinalIgnoreCase))
        {
            x = x with
            {
                ExpiresAt = new DateTimeOffset(now.AddDays(15)).ToUnixTimeMilliseconds(),
                OriginalPrice = 0,
                FinalPrice = 0,
                DiscountCode = null
            };
            final = 0;
            originalPrice = 0;
        }

        if (code.Length > 0)
        {
            var d = await db.DiscountCodes.FirstOrDefaultAsync(z => z.Code == code && z.Active);
            if (d == null) return BadRequest(new { message = "کد تخفیف معتبر نیست" });
            if (d.ExpiresAt.HasValue && d.ExpiresAt.Value <= now)
                return BadRequest(new { message = "کد تخفیف منقضی شده است" });
            if (d.MaxUses > 0 && d.UsedCount >= d.MaxUses)
                return BadRequest(new { message = "سقف استفاده از کد تخفیف تکمیل شده است" });

            final = Math.Max(0,
                x.OriginalPrice -
                (x.OriginalPrice * d.Percent / 100m) -
                d.FixedAmount);

            d.UsedCount++;
        }

        var activationCode = string.IsNullOrWhiteSpace(x.ActivationCode)
            ? CreateReadableCode(18)
            : x.ActivationCode.Trim();

        var lic = new License
        {
            StoreId = store.Id,
            LicenseId = string.IsNullOrWhiteSpace(x.LicenseId)
                ? $"LIC-{Guid.NewGuid():N}"[..20].ToUpperInvariant()
                : x.LicenseId.Trim(),
            ActivationCode = activationCode,
            Plan = x.Plan,
            Status = "ACTIVE",
            IssuedAt = now,
            ExpiresAt = DateTimeOffset.FromUnixTimeMilliseconds(x.ExpiresAt).UtcDateTime,
            OriginalPrice = originalPrice,
            FinalPrice = final,
            DiscountCode = code,
            FeaturesJson = JsonSerializer.Serialize(x.Features ?? new()),
            BusinessTypesJson = JsonSerializer.Serialize(x.BusinessTypes ?? new() { "*" }),
            MaxUsers = x.MaxUsers,
            Username = user.Username,
            InitialPassword = string.IsNullOrWhiteSpace(x.Password) ? "" : x.Password!,
            RecoveryCode = x.RecoveryCode ?? ""
        };

        // One LicenseId = Store.Code, as requested.
        store.Code = lic.LicenseId;

        db.Licenses.Add(lic);
        await db.SaveChangesAsync();

        return Ok(new
        {
            licenseId = lic.LicenseId,
            storeId = lic.StoreId,
            userId = user.Id,
            storeCode = store.Code,
            activationCode = lic.ActivationCode,
            username = lic.Username,
            expiresAt = new DateTimeOffset(lic.ExpiresAt).ToUnixTimeMilliseconds(),
            originalPrice = lic.OriginalPrice,
            finalPrice = lic.FinalPrice,
            discountCode = lic.DiscountCode
        });
    }

    [HttpPatch("licenses/{id}/status")]
    public async Task<IActionResult> Status(string id, StatusDto x)
    {
        if (!OkKey(Request)) return Unauthorized();

        var l = await db.Licenses.FirstOrDefaultAsync(a => a.LicenseId == id);
        if (l == null) return NotFound();

        var status = (x.Status ?? string.Empty).Trim().ToUpperInvariant();
        if (status is not ("ACTIVE" or "SUSPENDED" or "CANCELLED" or "RENEWED" or "EXPIRED"))
            return BadRequest(new { message = "وضعیت لایسنس نامعتبر است." });
        var oldStatus = l.Status;
        l.Status = status;
        await db.SaveChangesAsync();
        if (!string.Equals(oldStatus, status, StringComparison.OrdinalIgnoreCase))
        {
            await AppNotificationStore.PublishAsync(db, l.StoreId, "license_status_changed", "وضعیت لایسنس تغییر کرد",
                $"وضعیت لایسنس {l.LicenseId} به {status} تغییر کرد.", "{}",
                $"license-status:{l.LicenseId}:{status}:{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}");
        }

        return Ok(new { success = true, licenseId = l.LicenseId, status = l.Status });
    }

    [HttpPost("discounts")]
    public async Task<IActionResult> Discount(DiscountDto x)
    {
        if (!OkKey(Request)) return Unauthorized();

        var code = x.Code.Trim().ToUpperInvariant();
        if (string.IsNullOrWhiteSpace(code))
            return BadRequest(new { message = "کد تخفیف الزامی است" });

        if (await db.DiscountCodes.AnyAsync(d => d.Code == code))
            return Conflict(new { message = "کد تکراری است" });

        var d = new DiscountCode
        {
            Code = code,
            Percent = Math.Clamp(x.Percent, 0, 100),
            FixedAmount = Math.Max(0, x.FixedAmount),
            MaxUses = Math.Max(0, x.MaxUses),
            ExpiresAt = x.ExpiresAt,
            Active = true
        };

        db.DiscountCodes.Add(d);
        await db.SaveChangesAsync();

        return Ok(new
        {
            id = d.Id,
            code = d.Code,
            percent = d.Percent,
            fixedAmount = d.FixedAmount,
            maxUses = d.MaxUses,
            expiresAt = d.ExpiresAt
        });
    }

    [HttpGet("discounts")]
    public async Task<IActionResult> Discounts()
    {
        if (!OkKey(Request)) return Unauthorized();
        var rows = await db.DiscountCodes.AsNoTracking()
            .OrderByDescending(x => x.Id)
            .ToListAsync();

        return Ok(new
        {
            items = rows.Select(x => new
            {
                x.Id, x.Code, x.Percent, x.FixedAmount,
                x.MaxUses, x.UsedCount, x.ExpiresAt, x.Active
            })
        });
    }

    [HttpPost("discounts/quote")]
    public async Task<IActionResult> Quote(DiscountQuoteDto x)
    {
        if (!OkKey(Request)) return Unauthorized();

        var code = x.Code.Trim().ToUpperInvariant();
        var d = await db.DiscountCodes
            .FirstOrDefaultAsync(z => z.Code == code && z.Active);

        if (d == null) return NotFound(new { message = "کد تخفیف معتبر نیست" });
        if (d.ExpiresAt.HasValue && d.ExpiresAt.Value <= DateTime.UtcNow)
            return BadRequest(new { message = "کد تخفیف منقضی شده است" });
        if (d.MaxUses > 0 && d.UsedCount >= d.MaxUses)
            return BadRequest(new { message = "سقف استفاده از کد تخفیف تکمیل شده است" });

        var final = Math.Max(
            0,
            x.OriginalPrice -
            (x.OriginalPrice * d.Percent / 100m) -
            d.FixedAmount
        );

        return Ok(new
        {
            code = d.Code,
            originalPrice = x.OriginalPrice,
            finalPrice = final,
            percent = d.Percent,
            fixedAmount = d.FixedAmount
        });
    }

    [HttpGet("pricing")]
    public async Task<IActionResult> Pricing()
    {
        if (!OkKey(Request)) return Unauthorized();

        var rows = await db.PricingEntries.AsNoTracking()
            .OrderBy(x => x.PlanDays)
            .ToListAsync();

        if (rows.Count == 0)
            rows = await SeedPrices();

        return Ok(new
        {
            version = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            currency = "تومان",
            prices = rows.ToDictionary(x => x.PlanDays.ToString(), x => x.Price)
        });
    }

    [HttpPut("pricing")]
    public async Task<IActionResult> SavePricing(PricingDto x)
    {
        if (!OkKey(Request)) return Unauthorized();

        var incoming = x.Prices ?? new Dictionary<string, decimal>();

        foreach (var item in incoming)
        {
            if (!int.TryParse(item.Key, out var days)) continue;
            if (item.Value < 0) continue;

            var row = await db.PricingEntries
                .FirstOrDefaultAsync(z => z.PlanDays == days);

            if (row == null)
            {
                row = new PricingEntry { PlanDays = days };
                db.PricingEntries.Add(row);
            }

            row.Price = item.Value;
            row.Currency = string.IsNullOrWhiteSpace(x.Currency) ? "تومان" : x.Currency;
            row.UpdatedAt = DateTime.UtcNow;
        }

        await db.SaveChangesAsync();
        await AppNotificationStore.PublishAsync(db, null, "pricing_changed", "قیمت لایسنس‌ها به‌روزرسانی شد",
            "مدیریت قیمت بسته‌های لایسنس را تغییر داده است. برای مشاهده قیمت‌های جدید، صفحه را تازه‌سازی کنید.",
            System.Text.Json.JsonSerializer.Serialize(new { prices = incoming, currency = x.Currency ?? "تومان" }));

        return Ok(new
        {
            version = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            currency = x.Currency ?? "تومان",
            prices = incoming
        });
    }

    static string CreateReadableCode(int length)
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var rng = Random.Shared;
        return new string(Enumerable.Range(0, length)
            .Select(_ => chars[rng.Next(chars.Length)])
            .ToArray());
    }

    static string CreatePassword()
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
        var rng = Random.Shared;
        return new string(Enumerable.Range(0, 10)
            .Select(_ => chars[rng.Next(chars.Length)])
            .ToArray());
    }

    async Task<List<PricingEntry>> SeedPrices()
    {
        var defaults = new Dictionary<int, decimal>
        {
            [30] = 990000,
            [90] = 2490000,
            [180] = 4490000,
            [365] = 7990000
        };

        foreach (var item in defaults)
        {
            db.PricingEntries.Add(new PricingEntry
            {
                PlanDays = item.Key,
                Price = item.Value,
                Currency = "تومان"
            });
        }

        await db.SaveChangesAsync();

        return await db.PricingEntries.AsNoTracking()
            .OrderBy(x => x.PlanDays)
            .ToListAsync();
    }
}

public record LicenseDto(
    string StoreCode,
    string Plan,
    int DurationDays,
    decimal OriginalPrice,
    decimal FinalPrice,
    string? DiscountCode,
    List<string>? Features,
    List<string>? BusinessTypes,
    int MaxUsers,
    string? LicenseId,
    string? ActivationCode = null,
    string? Username = "admin",
    string? Password = null,
    string? RecoveryCode = null);

public record LicenseDtoByDevice(
    string DeviceId,
    string Plan,
    long ExpiresAt,
    decimal OriginalPrice,
    decimal FinalPrice,
    string? DiscountCode,
    List<string>? Features,
    List<string>? BusinessTypes,
    int MaxUsers,
    string? LicenseId,
    string? ActivationCode = null,
    string? Username = "admin",
    string? Password = null,
    string? RecoveryCode = null,
    string? StoreName = null,
    string? StoreType = null,
    string? BusinessTitle = null,
    string? Currency = null,
    string? Platform = null,
    string? DeviceName = null,
    string? CustomerName = null,
    string? Phone = null);

public record StatusDto(string Status);
public record DiscountDto(string Code, int Percent, decimal FixedAmount, int MaxUses, DateTime? ExpiresAt);
public record DiscountQuoteDto(string Code, decimal OriginalPrice);
public record PricingDto(Dictionary<string, decimal>? Prices, string? Currency);


public record ProvisionStoreDto(
    string StoreName, string? StoreType, string? BusinessTitle, string? Currency,
    string AdminName, string AdminPin, string? Phone, string? Username,
    string? DeviceId, string? Platform, string? DeviceName, string? Plan,
    int DurationDays, int MaxUsers, decimal OriginalPrice, decimal FinalPrice,
    List<string>? Features, List<string>? BusinessTypes);

public sealed record TrialPolicyDto(List<string>? Features, List<string>? BusinessTypes);

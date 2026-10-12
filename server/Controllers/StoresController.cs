using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Models;
using StoreMaster.Server.Services;
using System.Text.Json;
using BCrypt.Net;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("api/v1/stores")]
public class StoresController : ControllerBase
{
    private readonly StoreMasterDbContext db;

    public StoresController(StoreMasterDbContext db) => this.db = db;

    [HttpPost("bootstrap")]
    public async Task<IActionResult> Bootstrap(
        BootstrapDto x)
    {
        // Trial access is centrally controlled by the License Manager policy.
        // Client-supplied TrialFeatures/TrialBusinessTypes are deliberately ignored.
        var trialPolicy = await db.TrialPolicies.FirstOrDefaultAsync(x => x.Id == 1);
        if (trialPolicy == null)
        {
            trialPolicy = new TrialPolicy();
            db.TrialPolicies.Add(trialPolicy);
            await db.SaveChangesAsync();
        }
        var allowedFeatures = JsonSerializer.Deserialize<List<string>>(trialPolicy.FeaturesJson) ?? new List<string>();
        var allowedBusinesses = JsonSerializer.Deserialize<List<string>>(trialPolicy.BusinessTypesJson) ?? new List<string> { "*" };
        if (allowedFeatures.Count == 0)
            return StatusCode(503, new { message = "سیاست تریال هنوز توسط مدیر تنظیم نشده است." });
        var requestedBusiness = (x.StoreType ?? string.Empty).Trim().ToUpperInvariant();
        if (string.IsNullOrWhiteSpace(requestedBusiness))
            return BadRequest(new { message = "نوع کسب‌وکار الزامی است." });
        if (!allowedBusinesses.Contains("*") && !allowedBusinesses.Contains(requestedBusiness))
            return StatusCode(403, new { message = "فعلاً تریال برای این نوع کسب‌وکار توسط مدیر فعال نشده است." });

        var trialId =
            $"SM-{Guid.NewGuid():N}"[..14]
                .ToUpperInvariant();

        var store = new Store
        {
            Code = trialId,
            Name = x.StoreName,
            Type = x.StoreType,
            BusinessTitle = x.BusinessTitle,
            Currency = x.Currency
        };

        db.Stores.Add(store);

        var username =
            string.IsNullOrWhiteSpace(x.Username)
                ? "admin"
                : x.Username.Trim();

        var password =
            string.IsNullOrWhiteSpace(x.Password)
                ? x.AdminPin.Trim()
                : x.Password.Trim();

        if (password.Length < 4 || password.Length > 64)
            return BadRequest(new { message = "PIN/رمز باید بین 4 تا 64 رقم/کاراکتر باشد." });

        var u = new User
        {
            Username = username,
            Name = x.AdminName,
            Phone = x.Phone,
            PinHash = BCrypt.Net.BCrypt.HashPassword(password)
        };

        db.Users.Add(u);
        await db.SaveChangesAsync();

        var perms =
            PermissionService.Defaults(
                "OWNER");

        db.StoreUsers.Add(
            new StoreUser
            {
                StoreId = store.Id,
                UserId = u.Id,
                Role = "OWNER",
                PermissionsJson =
                    JsonSerializer.Serialize(
                        perms)
            });

        db.UserDevices.Add(
            new UserDevice
            {
                StoreId = store.Id,
                UserId = u.Id,
                DeviceId = x.DeviceId,
                Platform = x.Platform,
                Name = x.DeviceName
            });

        var license =
            new License
            {
                StoreId = store.Id,
                LicenseId = trialId,
                ActivationCode =
                    string.IsNullOrWhiteSpace(
                        x.ActivationCode)
                        ? trialId
                        : x.ActivationCode,
                Plan = "TRIAL",
                Status = "ACTIVE",
                ExpiresAt =
                    DateTime.UtcNow.AddDays(15),
                FeaturesJson = JsonSerializer.Serialize(allowedFeatures),
                // The trial instance is restricted to this store's business code;
                // the policy decides which business codes may start a trial.
                BusinessTypesJson = JsonSerializer.Serialize(new List<string> { requestedBusiness }),
                OriginalPrice = 0,
                FinalPrice = 0,
                MaxUsers = 5,
                Username = username,
                InitialPassword = password,
                RecoveryCode =
                    x.RecoveryCode ?? ""
            };

        db.Licenses.Add(license);
        await db.SaveChangesAsync();

        return Ok(
            new
            {
                storeId = store.Id,
                userId = u.Id,
                storeCode = store.Code,
                username,
                password,
                recoveryCode =
                    license.RecoveryCode,
                permissions = perms,
                licenseId = license.LicenseId,
                activationCode =
                    license.ActivationCode,
                licensePlan =
                    license.Plan,
                licenseStatus =
                    license.Status,
                licenseExpiresAt =
                    new DateTimeOffset(
                        license.ExpiresAt)
                    .ToUnixTimeMilliseconds(),
                trialDays = 15,
                trialFeatures = allowedFeatures,
                businessTypes = new List<string> { requestedBusiness }
            });
    }

    static string GeneratePassword()
    {
        const string chars =
            "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

        return new string(
            Enumerable.Range(0, 10)
                .Select(_ =>
                    chars[
                        Random.Shared.Next(
                            chars.Length)])
                .ToArray());
    }
}

public record BootstrapDto(
    string StoreName,
    string StoreType,
    string BusinessTitle,
    string AdminName,
    string AdminPin,
    string Phone,
    string DeviceId,
    string Currency,
    List<string>? TrialFeatures,
    List<string>? TrialBusinessTypes,
    string Platform = "",
    string DeviceName = "",
    string Username = "admin",
    string? Password = null,
    string? ActivationCode = null,
    string? RecoveryCode = null);

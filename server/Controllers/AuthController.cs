using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Services;
using StoreMaster.Server.Models;
using System.Text.Json;
using BCrypt.Net;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly StoreMasterDbContext db;
    private readonly JwtService jwt;

    public AuthController(StoreMasterDbContext db, JwtService jwt)
    {
        this.db = db;
        this.jwt = jwt;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginDto x)
    {
        int.TryParse(x.StoreCode, out var storeId);
        var store = await db.Stores
            .FirstOrDefaultAsync(
                z => z.Code == x.StoreCode ||
                     z.Id == storeId);

        if (store == null || !store.Active)
            return Unauthorized(new { message = "فروشگاه معتبر نیست" });

        StoreUser? su = null;
        User? u = null;

        var credential = string.IsNullOrWhiteSpace(x.Password)
            ? x.Pin
            : x.Password;

        if (x.UserId > 0)
        {
            su = await db.StoreUsers.FirstOrDefaultAsync(
                z => z.StoreId == store.Id &&
                     z.UserId == x.UserId &&
                     z.Active);

            if (su != null)
                u = await db.Users.FindAsync(su.UserId);
        }
        else if (!string.IsNullOrWhiteSpace(x.Username))
        {
            var pair = await (from sux in db.StoreUsers
                               join ux in db.Users on sux.UserId equals ux.Id
                               where sux.StoreId == store.Id
                                  && sux.Active
                                  && ux.Active
                                  && ux.Username == x.Username
                               select new { StoreUser = sux, User = ux })
                .FirstOrDefaultAsync();

            if (pair != null)
            {
                su = pair.StoreUser;
                u = pair.User;
            }
        }

        if (su == null || u == null || !u.Active ||
            !BCrypt.Net.BCrypt.Verify(credential, u.PinHash))
            return Unauthorized(new { message = "نام کاربری یا رمز عبور نادرست است" });

        var lic = await db.Licenses
            .Where(z =>
                z.StoreId == store.Id &&
                z.Status == "ACTIVE" &&
                z.ExpiresAt > DateTime.UtcNow)
            .OrderByDescending(z => z.ExpiresAt)
            .FirstOrDefaultAsync();

        if (lic == null)
            return StatusCode(
                403,
                new { message = "لایسنس فعال یا معتبر برای این فروشگاه وجود ندارد" });

        await RegisterDevice(
            store.Id,
            u.Id,
            x.DeviceId,
            x.Platform,
            x.DeviceName);

        var perms =
            JsonSerializer.Deserialize<List<string>>(
                su.PermissionsJson) ?? new();

        var features =
            JsonSerializer.Deserialize<List<string>>(
                lic.FeaturesJson) ?? new();

        var token =
            jwt.Create(
                u,
                su,
                store,
                perms,
                features,
                lic.ExpiresAt);

        return Ok(
            BuildSession(
                u,
                store,
                su,
                lic,
                token,
                perms,
                features));
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> Me()
    {
        if (!TryContext(
                out var uid,
                out var sid))
            return Unauthorized();

        var su = await db.StoreUsers.FirstOrDefaultAsync(
            z => z.UserId == uid &&
                 z.StoreId == sid &&
                 z.Active);

        var u = await db.Users.FindAsync(uid);
        var store = await db.Stores.FindAsync(sid);

        if (su == null ||
            u == null ||
            store == null)
            return Unauthorized();

        var lic = await db.Licenses
            .Where(z => z.StoreId == sid)
            .OrderByDescending(z => z.ExpiresAt)
            .FirstOrDefaultAsync();

        return Ok(
            new
            {
                userId = uid,
                storeId = sid,
                storeCode = store.Code,
                storeName = store.Name,
                storeType = store.Type,
                businessTitle = store.BusinessTitle,
                currency = store.Currency,
                username = u.Username,
                role = su.Role,
                permissions =
                    JsonSerializer.Deserialize<List<string>>(
                        su.PermissionsJson) ??
                    new List<string>(),
                license = lic == null
                    ? null
                    : new
                    {
                        licenseId = lic.LicenseId,
                        status = lic.Status,
                        expiresAt =
                            new DateTimeOffset(
                                lic.ExpiresAt)
                            .ToUnixTimeMilliseconds(),
                        plan = lic.Plan,
                        features =
                            JsonSerializer.Deserialize<List<string>>(
                                lic.FeaturesJson) ??
                            new List<string>(),
                        businessTypes =
                            JsonSerializer.Deserialize<List<string>>(
                                lic.BusinessTypesJson) ??
                            new List<string>()
                    }
            });
    }

    [HttpPost("logout-device")]
    [Authorize]
    public async Task<IActionResult> LogoutDevice(
        [FromBody] DeviceDto x)
    {
        if (!TryContext(
                out var uid,
                out var sid))
            return Unauthorized();

        var d = await db.UserDevices.FirstOrDefaultAsync(
            z => z.StoreId == sid &&
                 z.UserId == uid &&
                 z.DeviceId == x.DeviceId);

        if (d != null)
        {
            d.Active = false;
            await db.SaveChangesAsync();
        }

        return Ok(
            new { success = true });
    }

    private async Task RegisterDevice(
        int storeId,
        int userId,
        string deviceId,
        string platform,
        string name)
    {
        if (string.IsNullOrWhiteSpace(deviceId))
            return;

        var d = await db.UserDevices.FirstOrDefaultAsync(
            z => z.StoreId == storeId &&
                 z.UserId == userId &&
                 z.DeviceId == deviceId);

        if (d == null)
        {
            db.UserDevices.Add(
                new StoreMaster.Server.Models.UserDevice
                {
                    StoreId = storeId,
                    UserId = userId,
                    DeviceId = deviceId,
                    Platform = platform,
                    Name = name
                });
        }
        else
        {
            d.LastSeenAt = DateTime.UtcNow;
            d.Platform = platform;
            d.Name = name;
            d.Active = true;
        }

        await db.SaveChangesAsync();
    }

    private bool TryContext(
        out int uid,
        out int sid)
    {
        uid = int.TryParse(
            User.FindFirst("sub")?.Value,
            out var u)
            ? u
            : 0;

        sid = int.TryParse(
            User.FindFirst("storeId")?.Value,
            out var s)
            ? s
            : 0;

        return uid > 0 && sid > 0;
    }

    private static object BuildSession(
        StoreMaster.Server.Models.User u,
        StoreMaster.Server.Models.Store store,
        StoreMaster.Server.Models.StoreUser su,
        StoreMaster.Server.Models.License lic,
        string token,
        List<string> perms,
        List<string> features)
    {
        return new
        {
            accessToken = token,
            refreshToken = "",
            userId = u.Id,
            storeId = store.Id,
            storeCode = store.Code,
            username = u.Username,
            name = u.Name,
            role = su.Role,
            permissions = perms,
            features,
            businessTypes =
                JsonSerializer.Deserialize<List<string>>(
                    lic.BusinessTypesJson) ??
                new List<string>(),
            licenseId = lic.LicenseId,
            licensePlan = lic.Plan,
            licenseExpiresAt =
                new DateTimeOffset(
                    lic.ExpiresAt)
                .ToUnixTimeMilliseconds(),
            licenseStatus = lic.Status,
            storeName = store.Name,
            storeType = store.Type,
            businessTitle = store.BusinessTitle,
            currency = store.Currency
        };
    }
}

public record LoginDto(
    string StoreCode,
    int UserId,
    string Pin,
    string DeviceId,
    string Platform = "",
    string DeviceName = "",
    string? Username = null,
    string? Password = null);

public record DeviceDto(
    string DeviceId);

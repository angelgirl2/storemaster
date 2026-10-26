using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;
using StoreMaster.Server.Models;

namespace StoreMaster.Server.Services;

public sealed class LicenseExpirationNotifierService : BackgroundService
{
    private readonly IServiceScopeFactory scopes;
    private readonly ILogger<LicenseExpirationNotifierService> logger;

    public LicenseExpirationNotifierService(IServiceScopeFactory scopes, ILogger<LicenseExpirationNotifierService> logger)
    {
        this.scopes = scopes;
        this.logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Run on startup, then every 6 hours. Failures are logged and retried on the next pass.
        while (!stoppingToken.IsCancellationRequested)
        {
            try { await ScanAsync(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogWarning(ex, "StoreMaster license expiry notification scan failed; it will retry."); }
            try { await Task.Delay(TimeSpan.FromHours(6), stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }

    private async Task ScanAsync(CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<StoreMasterDbContext>();
        await AppNotificationStore.EnsureSchemaAsync(db, ct);
        var now = DateTime.UtcNow;
        var rows = await db.Licenses.AsNoTracking()
            .Where(x => x.Status == "ACTIVE" && x.ExpiresAt <= now.AddDays(7))
            .OrderBy(x => x.ExpiresAt)
            .Take(5000)
            .ToListAsync(ct);
        foreach (var lic in rows)
        {
            ct.ThrowIfCancellationRequested();
            if (lic.ExpiresAt <= now)
            {
                await AppNotificationStore.PublishAsync(db, lic.StoreId, "license_expired", "اعتبار لایسنس به پایان رسید",
                    $"اعتبار لایسنس {lic.LicenseId} به پایان رسیده است. برای تمدید با مدیریت تماس بگیرید.",
                    "{}", $"license-expired:{lic.LicenseId}:{new DateTimeOffset(lic.ExpiresAt).ToUnixTimeMilliseconds()}", ct);
                continue;
            }
            var remaining = (lic.ExpiresAt - now).TotalDays;
            var threshold = remaining <= 1 ? 1 : remaining <= 3 ? 3 : 7;
            await AppNotificationStore.PublishAsync(db, lic.StoreId, "license_expiring", "نزدیک شدن به انقضای لایسنس",
                $"لایسنس {lic.LicenseId} حدود {Math.Ceiling(remaining)} روز دیگر منقضی می‌شود.",
                "{}", $"license-expiring:{lic.LicenseId}:{new DateTimeOffset(lic.ExpiresAt).ToUnixTimeMilliseconds()}:{threshold}", ct);
        }
    }
}

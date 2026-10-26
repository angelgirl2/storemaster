# StoreMaster License Manager - repaired source

The supplied archive was a source-only bundle. It does not include Flutter platform folders or pubspec.yaml. Copy these repaired `lib`-style files into the existing License Manager Flutter project.

## Online test
Run the manager with:

`flutter run --dart-define=STORE_MASTER_ADMIN_ONLINE_ENABLED=true --dart-define=STORE_MASTER_API_URL=http://127.0.0.1:8080`

The HTTP client automatically targets `/api/v1` so paths match the ASP.NET Core server.

## Security
The Ed25519 signing key pair was rotated because the supplied private seed had been exposed in source. Keep the private seed only in the License Manager build environment and rotate again before production if this bundle is shared outside your trusted development environment.


برای failover از طریق Cloudflare، مقدار `STORE_MASTER_API_URL` را به URL Worker بده. وقتی Worker وضعیت active origin را مدیریت می‌کند، `STORE_MASTER_API_FALLBACK_URL` را خالی بگذار تا خواندن‌های کاربر از مسیر مستقیم VPS عبور نکنند و وضعیت failover را دور نزنند. مبدا اصلی Railway و مبدا دوم VPS در Worker تنظیم می‌شوند.

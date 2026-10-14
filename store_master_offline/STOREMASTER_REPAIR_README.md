# StoreMaster repair notes

## Shared source / analyzer root fixes
The User App now uses the provided `shared_src` catalogs for BusinessCatalog, PermissionCatalog, FeatureCatalog and OnlineSession.

## Online mode
The ASP.NET Core server uses .NET 8 and PostgreSQL. User and License Manager can be enabled with build-time defines.

User App:
`flutter run`

نسخه فعلی کاملاً آفلاین است. ارتباط بین Windows و Android فقط از طریق شبکه Wi-Fi محلی و سرویس LAN Sync انجام می‌شود و هیچ درخواست HTTP به API ابری ارسال نمی‌شود.

License Manager:
`flutter run --dart-define=STORE_MASTER_ADMIN_ONLINE_ENABLED=true --dart-define=STORE_MASTER_API_URL=http://YOUR_PC_IP:8080`

## License clock protection
Offline validation rejects a significant backward clock jump after a trusted local timestamp has been stored. In online mode, license validation obtains authoritative UTC milliseconds from the server and uses that value for expiry checks.

This is tamper resistance, not unbreakable DRM. A fully offline client cannot be made impossible to modify. Production authority remains the server.

## Key rotation
The signing key pair was rotated because a private signing seed appeared in the supplied source archive. Replace the generated private key with a new protected key before production release if that archive has been shared with anyone else.

## Server hardening
- Added `/api/v1/public/time` for authoritative online time.
- Added input validation for license/device requests.
- Fixed trial-renewal flow so it updates the existing license instead of inserting a duplicate LicenseId.
- Added activation-code collision checks.
- Scrubbed support bot secrets from the delivered server `.env`; restore them via environment variables on the deployment machine.

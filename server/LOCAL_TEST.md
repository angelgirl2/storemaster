# StoreMaster local online test

## 1) PostgreSQL
Create a database and user matching `appsettings.json` / `appsettings.Development.json`.

Example values:
- database: `storemaster`
- user: `storemaster`
- password: replace `CHANGE_ME_STRONG_PASSWORD`
- host: `localhost`
- port: `5432`

## 2) .NET 8
Install .NET 8 SDK and run from this folder:

`dotnet restore`

`dotnet build`

`dotnet run`

The API listens on `http://0.0.0.0:8080`.

## 3) Swagger / health / trusted server time
- Swagger: `http://localhost:8080/swagger`
- Health: `http://localhost:8080/health`
- Trusted time: `http://localhost:8080/api/v1/public/time`

## 4) Flutter User App
Use:

`flutter run --dart-define=STORE_MASTER_ONLINE_ENABLED=true --dart-define=STORE_MASTER_API_URL=http://127.0.0.1:8080`

For a physical Android device on the same Wi-Fi, replace `127.0.0.1` with the PC LAN IP, e.g. `http://192.168.1.10:8080`.

## 5) License Manager
Use:

`flutter run --dart-define=STORE_MASTER_ADMIN_ONLINE_ENABLED=true --dart-define=STORE_MASTER_API_URL=http://127.0.0.1:8080`

## 6) Offline anti-clock behavior
The User App stores its greatest observed local timestamp. Moving the Windows or Android system clock backwards by more than five minutes is rejected. Once online validation is available, license expiry uses the authoritative server time.

This is anti-rollback/tamper resistance, not unbreakable DRM. Production enforcement should remain server-authoritative.

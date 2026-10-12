# Store Master – Build & Deploy

## 1. Server

Create production secrets from `.env.example`, then:

```bash
cd store_master_server
docker compose up -d --build
```

Expose the API through HTTPS (for example `https://api.example.com`) using the included Nginx example. PostgreSQL stays private and is not exposed to the internet.

## 2. Client: Android + Windows

Run once on a machine that has Flutter installed:

```powershell
./prepare_platforms.ps1
```

or:

```bash
./prepare_platforms.sh
```

Then:

```bash
cd store_master_offline
flutter pub get
```

Build Windows:

```bash
flutter build windows --dart-define=STORE_MASTER_API_URL=https://api.example.com --dart-define=STORE_MASTER_ONLINE_REQUIRED=false
```

Build Android APK:

```bash
flutter build apk --release --dart-define=STORE_MASTER_API_URL=https://api.example.com --dart-define=STORE_MASTER_ONLINE_REQUIRED=false
```

Use `STORE_MASTER_ONLINE_REQUIRED=true` for a deployment that must authenticate against the server before allowing online login.

## 3. Same account on Windows and Android

The customer logs in with:

- Store Code
- Server User ID
- PIN

The same server account may have multiple registered devices. A Windows device and an Android device can therefore use the same account.

## 4. Offline mode

SQLite remains on each client. When the server is unavailable, local operations continue when the build uses `STORE_MASTER_ONLINE_REQUIRED=false`. Once the account is online again, the SQLite sync outbox sends changes to the server and server changes are applied back to the local database.

## 5. Roles and permissions

Roles:

`OWNER`, `ADMIN`, `MANAGER`, `SELLER`, `WAREHOUSE`, `ACCOUNTANT`, `CASHIER`, `CUSTOM`

Permissions are checked in Flutter for UI and on the API for security.

## 6. Important production settings

Never ship the sample JWT key, admin key, or PostgreSQL password. Replace all `CHANGE_ME` values. Put the API behind HTTPS and keep PostgreSQL on the private Docker network.

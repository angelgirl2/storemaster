# Store Master Server

## 1) Server
Ubuntu 22.04/24.04 + Docker recommended. Point a subdomain such as `api.your-domain.tld` to the server and put Nginx/SSL in front of the API.

## 2) Secrets
Change `ConnectionStrings`, `Jwt:Key`, and `Admin:Key`. Do not ship these in Flutter. The Flutter client receives only the HTTPS API URL.

## 3) Start
`docker compose up -d --build`

## 4) Flutter client
Build with:
`flutter build windows --dart-define=STORE_MASTER_API_URL=https://api.your-domain.tld --dart-define=STORE_MASTER_ONLINE_REQUIRED=true`

## 5) Architecture
PostgreSQL is the source of truth. SQLite remains local cache/queue. The server enforces JWT authentication and role/permission checks.

## 6) First setup
The included starter server uses `EnsureCreated` for first deployment; before production schema changes, generate and apply EF Core migrations.

The client setup calls `/stores/bootstrap`; a 15-day TRIAL is created with selected/default features. The returned storeCode is stored locally for later online login.

## 7) Admin
Use `X-Admin-Key` for developer-only admin endpoints until a dedicated admin login/role is added. Endpoints include store listing, role catalog, license creation/status, and discount code creation.

using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using StoreMaster.Server.Data;
using StoreMaster.Server.Services;
using System.Text;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

var railwayPort = Environment.GetEnvironmentVariable("PORT");
if (!int.TryParse(railwayPort, out var parsedPort) || parsedPort < 1 || parsedPort > 65535)
    parsedPort = 8080;
builder.WebHost.UseUrls($"http://0.0.0.0:{parsedPort}");

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 240,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

// Online is the server application's only supported production mode.
// The Flutter app remains offline-first; this API is the cloud source of truth.
var databaseMode = builder.Configuration["DatabaseMode"] ?? "Online";
if (!databaseMode.Equals("Online", StringComparison.OrdinalIgnoreCase))
    throw new InvalidOperationException("StoreMaster Server must run with DatabaseMode=Online.");

var connectionString = builder.Configuration.GetConnectionString("Default");
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException("ConnectionStrings:Default is required.");

builder.Services.AddDbContext<StoreMasterDbContext>(options =>
    options.UseNpgsql(connectionString, npgsql =>
    {
        npgsql.EnableRetryOnFailure(5, TimeSpan.FromSeconds(5), null);
    }));

builder.Services.AddScoped<JwtService>();
builder.Services.AddScoped<PermissionService>();

var key = builder.Configuration["Jwt:Key"];
var issuer = builder.Configuration["Jwt:Issuer"] ?? "StoreMaster";
var audience = builder.Configuration["Jwt:Audience"] ?? "StoreMasterClient";
if (string.IsNullOrWhiteSpace(key) || key.Length < 64)
    throw new InvalidOperationException("Jwt:Key must be at least 64 characters.");

if (builder.Environment.IsProduction())
{
    var adminKey = builder.Configuration["Admin:Key"];
    if (string.IsNullOrWhiteSpace(adminKey) || adminKey.Length < 32)
        throw new InvalidOperationException("Admin:Key must be at least 32 characters in production.");
}

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidIssuer = issuer,
            ValidAudience = audience,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key))
        };
    });

builder.Services.AddAuthorization();

builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownNetworks.Clear();
    o.KnownProxies.Clear();
});

var app = builder.Build();

app.UseForwardedHeaders();
var swaggerEnabled = builder.Configuration.GetValue<bool>("Swagger:Enabled");
if (swaggerEnabled)
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// Initial schema is created by the PostgreSQL init scripts. The optional
// AutoCreate switch is only for controlled local development and is disabled
// by the test/production compose files.
if (builder.Configuration.GetValue<bool>("Database:AutoCreate"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<StoreMasterDbContext>();
    await db.Database.EnsureCreatedAsync();
}
else
{
    // Fail fast when the API cannot reach PostgreSQL/PgBouncer.
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<StoreMasterDbContext>();
    await db.Database.CanConnectAsync();
}

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<StoreMasterDbContext>();
    await EnsureRuntimeSchemaAsync(db);
}

static async Task EnsureRuntimeSchemaAsync(StoreMasterDbContext db)
{
    // Idempotent schema repair for existing PostgreSQL/Railway volumes.
    // Create SupportTickets before ALTER TABLE so a fresh database can start too.
    await db.Database.ExecuteSqlRawAsync("""
        CREATE TABLE IF NOT EXISTS "SupportTickets" (
          "Id" bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
          "TicketCode" text NOT NULL DEFAULT '',
          "Type" text NOT NULL DEFAULT 'SUPPORT',
          "StoreCode" text NOT NULL DEFAULT '',
          "LicenseId" text NOT NULL DEFAULT '',
          "Username" text NOT NULL DEFAULT 'admin',
          "DeviceId" text NOT NULL DEFAULT '',
          "Contact" text NOT NULL DEFAULT '',
          "Message" text NOT NULL DEFAULT '',
          "Status" text NOT NULL DEFAULT 'OPEN',
          "AccessTokenHash" text NOT NULL DEFAULT '',
          "CreatedAt" timestamptz NOT NULL DEFAULT now()
        );
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "TicketCode" text NOT NULL DEFAULT '';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "Type" text NOT NULL DEFAULT 'SUPPORT';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "StoreCode" text NOT NULL DEFAULT '';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "LicenseId" text NOT NULL DEFAULT '';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "Username" text NOT NULL DEFAULT 'admin';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "DeviceId" text NOT NULL DEFAULT '';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "Contact" text NOT NULL DEFAULT '';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "Message" text NOT NULL DEFAULT '';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "Status" text NOT NULL DEFAULT 'OPEN';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "AccessTokenHash" text NOT NULL DEFAULT '';
        ALTER TABLE "SupportTickets" ADD COLUMN IF NOT EXISTS "CreatedAt" timestamptz NOT NULL DEFAULT now();
        """);

    await db.Database.ExecuteSqlRawAsync("""
        CREATE TABLE IF NOT EXISTS "SupportMessages" (
          "Id" bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
          "TicketId" bigint NOT NULL,
          "SenderRole" text NOT NULL DEFAULT 'CUSTOMER',
          "SenderName" text NOT NULL DEFAULT 'کاربر',
          "Message" text NOT NULL DEFAULT '',
          "CreatedAt" timestamptz NOT NULL DEFAULT now()
        );
        ALTER TABLE "SupportMessages" ADD COLUMN IF NOT EXISTS "TicketId" bigint NOT NULL DEFAULT 0;
        ALTER TABLE "SupportMessages" ADD COLUMN IF NOT EXISTS "SenderRole" text NOT NULL DEFAULT 'CUSTOMER';
        ALTER TABLE "SupportMessages" ADD COLUMN IF NOT EXISTS "SenderName" text NOT NULL DEFAULT 'کاربر';
        ALTER TABLE "SupportMessages" ADD COLUMN IF NOT EXISTS "Message" text NOT NULL DEFAULT '';
        ALTER TABLE "SupportMessages" ADD COLUMN IF NOT EXISTS "CreatedAt" timestamptz NOT NULL DEFAULT now();
        CREATE INDEX IF NOT EXISTS "IX_SupportMessages_TicketId_Id" ON "SupportMessages" ("TicketId", "Id");
        """);

    await db.Database.ExecuteSqlRawAsync("""
        CREATE TABLE IF NOT EXISTS "InvoiceShares" (
          "Id" bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
          "Token" text NOT NULL,
          "StoreId" integer NOT NULL,
          "StoreName" text NOT NULL DEFAULT '',
          "StorePhone" text NOT NULL DEFAULT '',
          "InvoiceNumber" text NOT NULL DEFAULT '',
          "DateText" text NOT NULL DEFAULT '',
          "CustomerName" text NOT NULL DEFAULT '',
          "Currency" text NOT NULL DEFAULT 'تومان',
          "ItemsJson" text NOT NULL DEFAULT '[]',
          "TotalAmount" numeric NOT NULL DEFAULT 0,
          "Discount" numeric NOT NULL DEFAULT 0,
          "FinalAmount" numeric NOT NULL DEFAULT 0,
          "PaidAmount" numeric NOT NULL DEFAULT 0,
          "DebtAmount" numeric NOT NULL DEFAULT 0,
          "CreatedAt" timestamptz NOT NULL DEFAULT now(),
          "ExpiresAt" timestamptz NOT NULL DEFAULT (now() + interval '7 days')
        );
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "Token" text NOT NULL DEFAULT '';
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "StoreId" integer NOT NULL DEFAULT 0;
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "StoreName" text NOT NULL DEFAULT '';
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "StorePhone" text NOT NULL DEFAULT '';
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "InvoiceNumber" text NOT NULL DEFAULT '';
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "DateText" text NOT NULL DEFAULT '';
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "CustomerName" text NOT NULL DEFAULT '';
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "Currency" text NOT NULL DEFAULT 'تومان';
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "ItemsJson" text NOT NULL DEFAULT '[]';
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "TotalAmount" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "Discount" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "FinalAmount" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "PaidAmount" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "DebtAmount" numeric NOT NULL DEFAULT 0;
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "CreatedAt" timestamptz NOT NULL DEFAULT now();
        ALTER TABLE "InvoiceShares" ADD COLUMN IF NOT EXISTS "ExpiresAt" timestamptz NOT NULL DEFAULT (now() + interval '7 days');
        CREATE UNIQUE INDEX IF NOT EXISTS "IX_InvoiceShares_Token" ON "InvoiceShares" ("Token");
        CREATE INDEX IF NOT EXISTS "IX_InvoiceShares_StoreId_CreatedAt" ON "InvoiceShares" ("StoreId", "CreatedAt");
        """);

    // CREATE TABLE IF NOT EXISTS alone does not repair a pre-existing table.
    // Add missing columns, repair blank/null values, and set defaults explicitly.
    await db.Database.ExecuteSqlRawAsync("""
        CREATE TABLE IF NOT EXISTS "TrialPolicies" (
          "Id" integer PRIMARY KEY,
          "FeaturesJson" text NOT NULL DEFAULT '["sales","customers","products"]',
          "BusinessTypesJson" text NOT NULL DEFAULT '["*"]',
          "UpdatedAt" timestamptz NOT NULL DEFAULT now()
        );
        ALTER TABLE "TrialPolicies"
          ADD COLUMN IF NOT EXISTS "FeaturesJson" text NOT NULL DEFAULT '["sales","customers","products"]';
        ALTER TABLE "TrialPolicies"
          ADD COLUMN IF NOT EXISTS "BusinessTypesJson" text NOT NULL DEFAULT '["*"]';
        ALTER TABLE "TrialPolicies"
          ADD COLUMN IF NOT EXISTS "UpdatedAt" timestamptz NOT NULL DEFAULT now();
        UPDATE "TrialPolicies" SET "FeaturesJson" = '["sales","customers","products"]'
          WHERE "FeaturesJson" IS NULL OR btrim("FeaturesJson") = '';
        UPDATE "TrialPolicies" SET "BusinessTypesJson" = '["*"]'
          WHERE "BusinessTypesJson" IS NULL OR btrim("BusinessTypesJson") = '';
        UPDATE "TrialPolicies" SET "UpdatedAt" = now() WHERE "UpdatedAt" IS NULL;
        ALTER TABLE "TrialPolicies" ALTER COLUMN "FeaturesJson" SET DEFAULT '["sales","customers","products"]';
        ALTER TABLE "TrialPolicies" ALTER COLUMN "BusinessTypesJson" SET DEFAULT '["*"]';
        ALTER TABLE "TrialPolicies" ALTER COLUMN "UpdatedAt" SET DEFAULT now();
        ALTER TABLE "TrialPolicies" ALTER COLUMN "FeaturesJson" SET NOT NULL;
        ALTER TABLE "TrialPolicies" ALTER COLUMN "BusinessTypesJson" SET NOT NULL;
        ALTER TABLE "TrialPolicies" ALTER COLUMN "UpdatedAt" SET NOT NULL;
        INSERT INTO "TrialPolicies" ("Id", "FeaturesJson", "BusinessTypesJson", "UpdatedAt")
        VALUES (1, '["sales","customers","products"]', '["*"]', now())
        ON CONFLICT ("Id") DO NOTHING;
        """);
}

app.Run();

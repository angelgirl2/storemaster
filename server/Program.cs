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
    // Idempotent forward-only schema updates for existing Railway volumes.
    // They cover only the new support-chat and invoice-share tables/column.
    await db.Database.ExecuteSqlRawAsync("ALTER TABLE \"SupportTickets\" ADD COLUMN IF NOT EXISTS \"AccessTokenHash\" text NOT NULL DEFAULT '';");
    await db.Database.ExecuteSqlRawAsync("""
        CREATE TABLE IF NOT EXISTS "SupportMessages" (
          "Id" bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
          "TicketId" bigint NOT NULL,
          "SenderRole" text NOT NULL DEFAULT 'CUSTOMER',
          "SenderName" text NOT NULL DEFAULT 'کاربر',
          "Message" text NOT NULL DEFAULT '',
          "CreatedAt" timestamptz NOT NULL DEFAULT now()
        );
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
          "ExpiresAt" timestamptz NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS "IX_InvoiceShares_Token" ON "InvoiceShares" ("Token");
        CREATE INDEX IF NOT EXISTS "IX_InvoiceShares_StoreId_CreatedAt" ON "InvoiceShares" ("StoreId", "CreatedAt");
        """);
    await db.Database.ExecuteSqlRawAsync("""
        CREATE TABLE IF NOT EXISTS "TrialPolicies" (
          "Id" integer PRIMARY KEY,
          "FeaturesJson" text NOT NULL DEFAULT '["sales","customers","products"]',
          "BusinessTypesJson" text NOT NULL DEFAULT '["*"]',
          "UpdatedAt" timestamptz NOT NULL DEFAULT now()
        );
        INSERT INTO "TrialPolicies" ("Id") VALUES (1) ON CONFLICT ("Id") DO NOTHING;
        """);
}

app.Run();

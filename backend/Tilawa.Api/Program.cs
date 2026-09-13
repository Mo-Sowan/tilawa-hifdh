using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Tilawa.Api.Auth;
using Tilawa.Api.Data;
using Tilawa.Api.Repositories;
using Tilawa.Api.Services;
using Tilawa.Api.Infrastructure.Mushaf;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.Configure<GoogleAuthOptions>(
    builder.Configuration.GetSection(GoogleAuthOptions.SectionName));
builder.Services.Configure<AppleAuthOptions>(
    builder.Configuration.GetSection(AppleAuthOptions.SectionName));

var jwtOptions = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>()
    ?? new JwtOptions();

if (string.IsNullOrWhiteSpace(jwtOptions.SigningKey))
{
    if (!builder.Environment.IsDevelopment())
    {
        // Fail loudly rather than signing production tokens with a key that
        // is in source control.
        throw new InvalidOperationException(
            "Jwt:SigningKey must be configured. Set it via configuration or the " +
            "Jwt__SigningKey environment variable.");
    }

    // Ephemeral development key: restarting the API invalidates old tokens,
    // which is the correct behaviour for a throwaway secret.
    jwtOptions.SigningKey = Convert.ToBase64String(
        System.Security.Cryptography.RandomNumberGenerator.GetBytes(48));
    builder.Services.PostConfigure<JwtOptions>(o => o.SigningKey = jwtOptions.SigningKey);
}
else if (Encoding.UTF8.GetByteCount(jwtOptions.SigningKey) < 32)
{
    throw new InvalidOperationException("Jwt:SigningKey must be at least 32 bytes long.");
}

builder.Services.AddControllers();
builder.Services.AddHttpContextAccessor();
builder.Services.AddHttpClient();
builder.Services.AddOptions<MushafCacheOptions>()
    .Bind(builder.Configuration.GetSection(MushafCacheOptions.SectionName))
    .ValidateDataAnnotations()
    .Validate(o => Uri.TryCreate(o.UpstreamRoot, UriKind.Absolute, out var uri) && uri.Scheme == "https",
        "MushafCache:UpstreamRoot must be an absolute HTTPS URL.")
    .ValidateOnStart();
builder.Services.AddHttpClient(DiskMushafPageCache.HttpClientName, client =>
{
    // The cache applies a linked timeout to headers, body transfer AND encoding.
    client.Timeout = Timeout.InfiniteTimeSpan;
});
builder.Services.AddSingleton<IMushafPageCache, DiskMushafPageCache>();
builder.Services.AddHostedService<MushafCachePrewarmer>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Tilawa API", Version = "v1" });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Paste the access token returned by /api/v1/auth/google or /apple.",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer",
                },
            },
            Array.Empty<string>()
        },
    });
});

// The mobile app is not a browser origin, but the web build and Swagger are.
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy("Default", policy =>
    {
        if (allowedOrigins.Length == 0)
        {
            policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
        }
        else
        {
            policy.WithOrigins(allowedOrigins)
                .AllowAnyMethod()
                .AllowAnyHeader()
                .AllowCredentials();
        }
    });
});

var databasePath = Path.Combine(builder.Environment.ContentRootPath, "App_Data", "tilawa.db");
Directory.CreateDirectory(Path.GetDirectoryName(databasePath)!);
builder.Services.AddDbContext<TilawaDbContext>(options =>
    options.UseSqlite($"Data Source={databasePath}"));

builder.Services.AddScoped<IUserContext, HttpUserContext>();
builder.Services.AddScoped<IRevisionRepository, RevisionRepository>();
builder.Services.AddScoped<IRevisionService, RevisionService>();
builder.Services.AddScoped<ILeaderboardService, LeaderboardService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IIdentityTokenVerifier, GoogleIdentityTokenVerifier>();
builder.Services.AddScoped<IIdentityTokenVerifier, AppleIdentityTokenVerifier>();

// Apple's signing keys rotate; the configuration manager caches them and
// refreshes on its own schedule so token checks stay local.
builder.Services.AddSingleton<IConfigurationManager<OpenIdConnectConfiguration>>(provider =>
{
    var appleOptions = builder.Configuration
        .GetSection(AppleAuthOptions.SectionName)
        .Get<AppleAuthOptions>() ?? new AppleAuthOptions();

    return new ConfigurationManager<OpenIdConnectConfiguration>(
        appleOptions.MetadataAddress,
        new OpenIdConnectConfigurationRetriever(),
        new HttpDocumentRetriever { RequireHttps = true })
    {
        AutomaticRefreshInterval = TimeSpan.FromHours(12),
        RefreshInterval = TimeSpan.FromMinutes(5),
    };
});

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtOptions.Audience,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtOptions.SigningKey)),
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });

builder.Services.AddAuthorization();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    var permitLimit = builder.Configuration.GetValue("RateLimiting:PermitLimit", 120);
    var windowSeconds = builder.Configuration.GetValue("RateLimiting:WindowSeconds", 60);
    var queueLimit = builder.Configuration.GetValue("RateLimiting:QueueLimit", 20);

    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            // Per user once authenticated, per IP before that, so one busy
            // client cannot exhaust another's budget behind a shared NAT.
            partitionKey: context.User.Identity?.IsAuthenticated == true
                ? context.User.Identity!.Name ?? context.User.FindFirst("sub")?.Value ?? "user"
                : context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = permitLimit,
                QueueLimit = queueLimit,
                Window = TimeSpan.FromSeconds(windowSeconds),
            }));
});

var app = builder.Build();

// Migrations rather than EnsureCreated: the schema has to survive upgrades
// without dropping a user's revision history.
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<TilawaDbContext>();
    dbContext.Database.Migrate();
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("Default");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }))
    .AllowAnonymous()
    .DisableRateLimiting();

app.Run();

/// <summary>
/// Exposed so the integration tests can spin the API up in-process.
/// </summary>
public partial class Program;

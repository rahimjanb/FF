using System.Security.Claims;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Features.Access;
using FitnessFormulasi.Api.Features.Legal;
using FitnessFormulasi.Api.Features.Banners;
using FitnessFormulasi.Api.Features.Integrations;
using FitnessFormulasi.Api.Features.Ai;
using FitnessFormulasi.Api.Features.Nutrition;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;

// ---- Configuration (secrets come from environment variables or user-secrets, never from source) ----
builder.Services.AddOptions<JwtOptions>().Bind(config.GetSection(JwtOptions.Section)).ValidateDataAnnotations().ValidateOnStart();
builder.Services.Configure<ClubOptions>(config.GetSection(ClubOptions.Section));

var connectionString = config.GetConnectionString("Default");
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException("ConnectionStrings:Default is not configured.");
// The interceptor wakes the turnstile synchronisation after changes to memberships, visits and face photos.
builder.Services.AddSingleton<AccessSyncSignal>();
builder.Services.AddSingleton<AccessChangeInterceptor>();
builder.Services.AddDbContext<AppDbContext>((sp, o) => o.UseNpgsql(connectionString)
    .AddInterceptors(sp.GetRequiredService<AccessChangeInterceptor>()));

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<IClubClock, ClubClock>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpCurrentUser>();
builder.Services.AddScoped<IPasswordHasher<User>, PasswordHasher<User>>();
builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<Profiles>();
builder.Services.AddScoped<NotificationService>();
builder.Services.AddScoped<MembershipService>();
builder.Services.AddScoped<AccountDeletionService>();
builder.Services.AddScoped<MembershipRequestService>();
builder.Services.AddSingleton<PassTokenService>();
builder.Services.AddScoped<CheckInService>();
builder.Services.AddScoped<TrainerRequestService>();
builder.Services.AddScoped<TrainingSessionService>();
builder.Services.Configure<IntegrationsOptions>(config.GetSection(IntegrationsOptions.Section));
builder.Services.AddSingleton<SecretProtector>();
builder.Services.AddScoped<IntegrationSettingsService>();
builder.Services.Configure<MediaOptions>(config.GetSection(MediaOptions.Section));
builder.Services.AddSingleton<MediaStorage>();

// Face recognition terminals (Hikvision ISAPI): face photos, synchronisation with memberships, pass events.
builder.Services.Configure<AccessOptions>(config.GetSection(AccessOptions.Section));
builder.Services.Configure<LegalOptions>(config.GetSection(LegalOptions.Section));
builder.Services.AddSingleton<AccessSyncLock>();
builder.Services.AddSingleton<IIsapiHandlerFactory, IsapiHandlerFactory>();
builder.Services.AddSingleton<HikvisionTerminalFactory>();
builder.Services.AddScoped<AccessPlanner>();
builder.Services.AddScoped<AccessSyncService>();
builder.Services.AddScoped<FaceService>();
builder.Services.AddHostedService<AccessSyncWorker>();

// AI Food Scanner, food diary, nutrition analytics and consultant (Features/Nutrition, Features/Ai).
// The AI provider is chosen by configuration (Ai__Provider, Ai__ApiKey); without it every AI call answers ai_not_configured.
builder.Services.Configure<AiOptions>(config.GetSection(AiOptions.Section));
var aiOptions = config.GetSection(AiOptions.Section).Get<AiOptions>() ?? new AiOptions();
if (string.Equals(aiOptions.Provider, "Anthropic", StringComparison.OrdinalIgnoreCase) && aiOptions.IsEnabled)
    builder.Services.AddSingleton<IAiModelClient, AnthropicAiClient>();
else if (string.Equals(aiOptions.Provider, "None", StringComparison.OrdinalIgnoreCase) || !aiOptions.IsEnabled)
    builder.Services.AddSingleton<IAiModelClient, DisabledAiClient>();
else
    throw new InvalidOperationException($"Ai:Provider '{aiOptions.Provider}' is not supported. Use Anthropic or None.");
builder.Services.AddScoped<AiGateway>();
builder.Services.AddMemoryCache();
builder.Services.Configure<FoodDataOptions>(config.GetSection(FoodDataOptions.Section));
var foodData = config.GetSection(FoodDataOptions.Section).Get<FoodDataOptions>() ?? new FoodDataOptions();
builder.Services.AddHttpClient<IBarcodeProductSource, OpenFoodFactsSource>(c =>
{
    c.BaseAddress = new Uri(foodData.OpenFoodFactsBaseUrl);
    c.Timeout = TimeSpan.FromSeconds(foodData.TimeoutSeconds);
    c.DefaultRequestHeaders.UserAgent.ParseAdd(foodData.UserAgent);
});
builder.Services.AddHttpClient<IFoodSearchSource, UsdaFoodSearchSource>(c =>
{
    c.BaseAddress = new Uri(foodData.UsdaBaseUrl);
    c.Timeout = TimeSpan.FromSeconds(foodData.TimeoutSeconds);
});
builder.Services.AddSingleton<FoodCatalog>();
builder.Services.AddScoped<FoodDatabaseService>();
builder.Services.AddScoped<FoodRecognitionService>();
builder.Services.AddScoped<NutritionProfileService>();
builder.Services.AddScoped<NutritionSummaryService>();
builder.Services.AddScoped<FoodScannerService>();
builder.Services.AddScoped<FoodDiaryService>();
builder.Services.AddScoped<NutritionAnalyticsService>();
builder.Services.AddScoped<NutritionDataTools>();
builder.Services.AddScoped<NutritionConsultantService>();
builder.Services.AddScoped<NutritionReportService>();

// SMS: the logging sender exists only in Development. Production answers 503 until a real provider is connected.
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddSingleton<ISmsSender, DevelopmentSmsSender>();
    builder.Services.AddSingleton<DevLogins>(); // short logins 1/1, 2/2, 3/3 for manual testing
}
else
    builder.Services.AddSingleton<ISmsSender, NotConfiguredSmsSender>();

// ---- Authentication & authorization ----
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
builder.Services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<IOptions<JwtOptions>>((o, jwt) =>
    {
        o.MapInboundClaims = true;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = jwt.Value.Issuer,
            ValidAudience = jwt.Value.Audience,
            IssuerSigningKey = TokenService.SigningKey(jwt.Value),
            ValidateIssuerSigningKey = true,
            ClockSkew = TimeSpan.FromSeconds(30),
            RoleClaimType = ClaimTypes.Role,
            NameClaimType = ClaimTypes.Name,
        };
        o.Events = new JwtBearerEvents
        {
            // Blocked users and role changes take effect immediately, not after token expiry.
            OnTokenValidated = async ctx =>
            {
                var db = ctx.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
                var id = Guid.TryParse(ctx.Principal?.FindFirstValue(ClaimTypes.NameIdentifier), out var g) ? g : Guid.Empty;
                var role = ctx.Principal?.FindFirstValue(ClaimTypes.Role);
                var state = await db.Users.Where(u => u.Id == id && u.Status == UserStatus.Active && u.Role.Name == role)
                    .Select(u => new { u.MustChangePassword, u.CanManageIntegrations }).SingleOrDefaultAsync(ctx.HttpContext.RequestAborted);
                if (state is null)
                {
                    ctx.Fail("User is inactive or role changed.");
                    return;
                }
                ctx.HttpContext.Items[PasswordChangeGate.ItemKey] = state.MustChangePassword;
                // Permissions come from the database, not the token, so revoking one takes effect on the next request.
                if (state.CanManageIntegrations && role == RoleNames.Admin && ctx.Principal?.Identity is ClaimsIdentity identity)
                    identity.AddClaim(new Claim(Permissions.ClaimType, Permissions.ManageIntegrations));
            },
        };
    });
builder.Services.AddAuthorization(o => o.AddPolicy(Permissions.ManageIntegrations, p => p
    .RequireRole(RoleNames.Admin).RequireClaim(Permissions.ClaimType, Permissions.ManageIntegrations)));

builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy(RateLimits.Auth, http => RateLimitPartition.GetFixedWindowLimiter(
        http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = config.GetValue("RateLimiting:AuthPermitPerMinute", 20),
            Window = TimeSpan.FromMinutes(1),
        }));
    // AI requests cost money: a few per minute per user (daily limits are in AiGateway). Lookups: barcodes and search.
    o.AddPolicy(RateLimits.Ai, http => RateLimitPartition.GetFixedWindowLimiter(
        http.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = config.GetValue("RateLimiting:AiPermitPerMinute", 6),
            Window = TimeSpan.FromMinutes(1),
        }));
    o.AddPolicy(RateLimits.Lookup, http => RateLimitPartition.GetFixedWindowLimiter(
        http.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = config.GetValue("RateLimiting:LookupPermitPerMinute", 60),
            Window = TimeSpan.FromMinutes(1),
        }));
});

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .WithOrigins(config.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [])
    .AllowAnyHeader().AllowAnyMethod()));

// ---- MVC, validation, errors ----
builder.Services.AddControllers(o => o.Filters.Add<PasswordChangeGate>())
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()))
    .ConfigureApiBehaviorOptions(o => o.InvalidModelStateResponseFactory = ctx =>
    {
        var problem = ctx.HttpContext.RequestServices.GetRequiredService<Microsoft.AspNetCore.Mvc.Infrastructure.ProblemDetailsFactory>()
            .CreateValidationProblemDetails(ctx.HttpContext, ctx.ModelState, StatusCodes.Status400BadRequest, "Validation failed.");
        problem.Extensions["code"] = "validation_failed";
        return new BadRequestObjectResult(problem) { ContentTypes = { "application/problem+json" } };
    });
builder.Services.AddApiErrorHandling();
builder.Services.AddHealthChecks().AddCheck<DatabaseHealthCheck>("database");

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Fitness Formulasi API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http, Scheme = "bearer", BearerFormat = "JWT",
        Description = "Access token from /api/auth/login",
    });
    c.AddSecurityRequirement(doc => new OpenApiSecurityRequirement { [new OpenApiSecuritySchemeReference("Bearer", doc)] = [] });
    c.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, "FitnessFormulasi.Api.xml"));
});

var app = builder.Build();
_ = app.Services.GetRequiredService<SecretProtector>(); // fail fast on a malformed encryption key

app.UseExceptionHandler();
app.UseStatusCodePages();
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseHsts();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapControllers();
app.MapHealthChecks("/health");

await DbInitializer.InitializeAsync(app.Services);
app.Run();

public partial class Program;

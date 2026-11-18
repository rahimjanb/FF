using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>
/// AI Food Scanner. Photos are multipart/form-data JPEG (≤ 6 MB); results are scoped to the signed-in client.
/// Nothing is written to the food diary here.
/// </summary>
[ApiController]
[Route("api/food-scanner")]
[Authorize(Roles = RoleNames.Client)]
[Produces("application/json")]
public class FoodScannerController(FoodScannerService scanner, Profiles profiles) : ControllerBase
{
    /// <summary>Recognizes the dishes on a food photo and calculates their nutrition from the food database.</summary>
    [HttpPost("analyze")]
    [EnableRateLimiting(RateLimits.Ai)]
    [RequestSizeLimit(8 * 1024 * 1024)]
    [Consumes("multipart/form-data")]
    public async Task<FoodScanDto> Analyze(IFormFile? photo, [FromForm] string? hint, CancellationToken ct) =>
        await scanner.AnalyzePhotoAsync(await profiles.ClientIdAsync(ct), photo, hint, ct);

    /// <summary>Reads a nutrition label photo and saves the product as the client's own (with the barcode, if given).</summary>
    [HttpPost("label")]
    [EnableRateLimiting(RateLimits.Ai)]
    [RequestSizeLimit(8 * 1024 * 1024)]
    [Consumes("multipart/form-data")]
    public async Task<FoodScanDto> Label(IFormFile? photo, [FromForm] string? barcode, CancellationToken ct) =>
        await scanner.ReadLabelAsync(await profiles.ClientIdAsync(ct), photo, string.IsNullOrWhiteSpace(barcode) ? null : barcode.Trim(), ct);

    /// <summary>Finds a packaged product by barcode (the client's labels, then Open Food Facts). 404 barcode_not_found.</summary>
    [HttpPost("barcode")]
    [EnableRateLimiting(RateLimits.Lookup)]
    public async Task<FoodScanDto> Barcode(BarcodeRequest req, CancellationToken ct) =>
        await scanner.BarcodeAsync(await profiles.ClientIdAsync(ct), req.Code, ct);

    [HttpGet("history")]
    public async Task<PagedResult<FoodScanSummaryDto>> History([FromQuery] PageQuery page, CancellationToken ct) =>
        await scanner.HistoryAsync(await profiles.ClientIdAsync(ct), page, ct);

    [HttpGet("result/{id:guid}")]
    public async Task<FoodScanDto> Get(Guid id, CancellationToken ct) => await scanner.GetAsync(await profiles.ClientIdAsync(ct), id, ct);

    /// <summary>Saves the client's correction of a dish and returns the recalculated result.</summary>
    [HttpPut("result/{id:guid}")]
    public async Task<FoodScanDto> Update(Guid id, UpdateDishRequest req, CancellationToken ct) =>
        await scanner.UpdateDishAsync(await profiles.ClientIdAsync(ct), id, req, ct);

    /// <summary>Deletes the scan and its photo.</summary>
    [HttpDelete("result/{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await scanner.DeleteAsync(await profiles.ClientIdAsync(ct), id, ct);
        return NoContent();
    }

    [HttpGet("result/{id:guid}/photo")]
    [Produces("image/jpeg")]
    public async Task<IActionResult> Photo(Guid id, CancellationToken ct)
    {
        var path = await scanner.PhotoPathAsync(await profiles.ClientIdAsync(ct), id, ct);
        Response.Headers.CacheControl = "private, max-age=86400";
        return PhysicalFile(path, "image/jpeg");
    }

    /// <summary>Deletes only the photo; the recognized dishes and diary entries stay.</summary>
    [HttpDelete("result/{id:guid}/photo")]
    public async Task<IActionResult> DeletePhoto(Guid id, CancellationToken ct)
    {
        await scanner.DeletePhotoAsync(await profiles.ClientIdAsync(ct), id, ct);
        return NoContent();
    }
}

/// <summary>Food diary of the signed-in client. Dates are club-local (yyyy-MM-dd).</summary>
[ApiController]
[Route("api/food-diary")]
[Authorize(Roles = RoleNames.Client)]
[Produces("application/json")]
public class FoodDiaryController(FoodDiaryService diary, Profiles profiles) : ControllerBase
{
    [HttpGet]
    public async Task<DiaryDayDto> Day([FromQuery] DateOnly? date, CancellationToken ct) =>
        await diary.DayAsync(await profiles.ClientIdAsync(ct), date, ct);

    /// <summary>Recently eaten foods, one per name, for "repeat".</summary>
    [HttpGet("recent")]
    public async Task<List<DiaryEntryDto>> Recent([FromQuery] int take = 20, CancellationToken ct = default) =>
        await diary.RecentAsync(await profiles.ClientIdAsync(ct), take, ct);

    [HttpGet("{id:guid}")]
    public async Task<DiaryEntryDto> Get(Guid id, CancellationToken ct) => await diary.GetAsync(await profiles.ClientIdAsync(ct), id, ct);

    [HttpPost]
    public async Task<ActionResult<DiaryEntryDto>> Create(SaveDiaryEntryRequest req, CancellationToken ct)
    {
        var entry = await diary.CreateAsync(await profiles.ClientIdAsync(ct), req, ct);
        return CreatedAtAction(nameof(Get), new { id = entry.Id }, entry);
    }

    [HttpPut("{id:guid}")]
    public async Task<DiaryEntryDto> Update(Guid id, SaveDiaryEntryRequest req, CancellationToken ct) =>
        await diary.UpdateAsync(await profiles.ClientIdAsync(ct), id, req, ct);

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await diary.DeleteAsync(await profiles.ClientIdAsync(ct), id, ct);
        return NoContent();
    }

    [HttpPost("{id:guid}/repeat")]
    public async Task<ActionResult<DiaryEntryDto>> Repeat(Guid id, RepeatDiaryEntryRequest req, CancellationToken ct)
    {
        var entry = await diary.RepeatAsync(await profiles.ClientIdAsync(ct), id, req, ct);
        return CreatedAtAction(nameof(Get), new { id = entry.Id }, entry);
    }
}

/// <summary>Nutrition profile and target, analytics, AI reports and consultant, food database.</summary>
[ApiController]
[Route("api/nutrition")]
[Authorize(Roles = RoleNames.Client)]
[Produces("application/json")]
public class NutritionController(
    NutritionProfileService nutritionProfiles, NutritionAnalyticsService analytics, NutritionReportService reports,
    NutritionConsultantService consultant, FoodDatabaseService foods, Profiles profiles) : ControllerBase
{
    [HttpGet("profile")]
    public async Task<NutritionProfileDto> GetProfile(CancellationToken ct) => await nutritionProfiles.GetAsync(await profiles.ClientIdAsync(ct), ct);

    [HttpPut("profile")]
    public async Task<NutritionProfileDto> UpdateProfile(UpdateNutritionProfileRequest req, CancellationToken ct) =>
        await nutritionProfiles.UpdateAsync(await profiles.ClientIdAsync(ct), req, ct);

    /// <summary>The client agrees that photos and nutrition data (no name or phone) are sent to the AI service.</summary>
    [HttpPost("ai-consent")]
    public async Task<NutritionProfileDto> GiveConsent(CancellationToken ct) =>
        await nutritionProfiles.SetConsentAsync(await profiles.ClientIdAsync(ct), true, ct);

    [HttpDelete("ai-consent")]
    public async Task<NutritionProfileDto> RevokeConsent(CancellationToken ct) =>
        await nutritionProfiles.SetConsentAsync(await profiles.ClientIdAsync(ct), false, ct);

    [HttpGet("daily")]
    public async Task<NutritionDailyDto> Daily([FromQuery] DateOnly? date, CancellationToken ct) =>
        await analytics.DailyAsync(await profiles.ClientIdAsync(ct), date, ct);

    /// <summary>The 7 days ending at <paramref name="end"/> (today by default).</summary>
    [HttpGet("weekly")]
    public async Task<NutritionPeriodDto> Weekly([FromQuery] DateOnly? end, CancellationToken ct) =>
        await analytics.WeeklyAsync(await profiles.ClientIdAsync(ct), end, ct);

    /// <summary>A calendar month, <paramref name="month"/> as yyyy-MM (the current one by default).</summary>
    [HttpGet("monthly")]
    public async Task<NutritionPeriodDto> Monthly([FromQuery] string? month, CancellationToken ct) =>
        await analytics.MonthlyAsync(await profiles.ClientIdAsync(ct), month, ct);

    /// <summary>AI report for a day or the week ending at <paramref name="date"/>; reused while the data is unchanged.</summary>
    [HttpGet("report")]
    [EnableRateLimiting(RateLimits.Ai)]
    public async Task<NutritionReportDto> Report([FromQuery] NutritionReportPeriod period, [FromQuery] DateOnly? date,
        [FromQuery] string? locale, CancellationToken ct) =>
        await reports.GetAsync(await profiles.ClientIdAsync(ct), period, date, locale, ct);

    [HttpPost("consultant/chat")]
    [EnableRateLimiting(RateLimits.Ai)]
    public async Task<ConsultantReplyDto> Chat(ConsultantChatRequest req, CancellationToken ct) =>
        await consultant.ChatAsync(await profiles.ClientIdAsync(ct), req, ct);

    // ---- Food database ----

    [HttpGet("foods/search")]
    [EnableRateLimiting(RateLimits.Lookup)]
    public async Task<FoodSearchResultDto> Search([FromQuery] string? q, [FromQuery] int take = 20, CancellationToken ct = default) =>
        await foods.SearchAsync(await profiles.ClientIdAsync(ct), q, take, ct);

    [HttpGet("foods/{id:guid}")]
    public async Task<FoodProductDto> Product(Guid id, CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        return FoodDatabaseService.ToDto(await foods.ProductAsync(clientId, id, ct), clientId);
    }

    /// <summary>A product of the client's own (e.g. typed in from a package).</summary>
    [HttpPost("foods")]
    public async Task<ActionResult<FoodProductDto>> CreateProduct(CreateFoodProductRequest req, CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        var product = await foods.CreateOwnAsync(clientId, req, NutritionSource.User, null, null, ct);
        return CreatedAtAction(nameof(Product), new { id = product.Id }, FoodDatabaseService.ToDto(product, clientId));
    }

    [HttpDelete("foods/{id:guid}")]
    public async Task<IActionResult> DeleteProduct(Guid id, CancellationToken ct)
    {
        await foods.DeleteOwnAsync(await profiles.ClientIdAsync(ct), id, ct);
        return NoContent();
    }

    [HttpGet("recipes/{id:guid}")]
    public async Task<FoodRecipeDto> Recipe(Guid id, CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        return FoodDatabaseService.RecipeDto(await foods.RecipeAsync(clientId, id, ct), clientId);
    }

    [HttpPost("recipes")]
    public async Task<ActionResult<FoodRecipeDto>> CreateRecipe(SaveRecipeRequest req, CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        var recipe = await foods.SaveRecipeAsync(clientId, null, req, ct);
        return CreatedAtAction(nameof(Recipe), new { id = recipe.Id }, FoodDatabaseService.RecipeDto(recipe, clientId));
    }

    [HttpPut("recipes/{id:guid}")]
    public async Task<FoodRecipeDto> UpdateRecipe(Guid id, SaveRecipeRequest req, CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        return FoodDatabaseService.RecipeDto(await foods.SaveRecipeAsync(clientId, id, req, ct), clientId);
    }

    [HttpDelete("recipes/{id:guid}")]
    public async Task<IActionResult> DeleteRecipe(Guid id, CancellationToken ct)
    {
        await foods.DeleteRecipeAsync(await profiles.ClientIdAsync(ct), id, ct);
        return NoContent();
    }
}

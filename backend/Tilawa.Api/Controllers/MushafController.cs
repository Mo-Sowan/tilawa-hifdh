using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Tilawa.Api.Services;

namespace Tilawa.Api.Controllers;

[ApiController]
[Route("api/v1/mushaf")]
[AllowAnonymous]
public sealed class MushafController(IMushafPageCache cache, ILogger<MushafController> logger) : ControllerBase
{
    [HttpGet("page/{pageNumber:int}")]
    [DisableRateLimiting]
    public async Task<IActionResult> GetPageImage(int pageNumber, CancellationToken cancellationToken)
    {
        Response.Headers.CacheControl = "no-store";
        if (pageNumber is < 1 or > 604)
            return BadRequest("Page number must be between 1 and 604.");
        try
        {
            var page = await cache.GetAsync(pageNumber, cancellationToken);
            Response.Headers.CacheControl = "public, max-age=31536000, immutable";
            return PhysicalFile(page.FullPath, page.ContentType, enableRangeProcessing: true);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
        catch (OperationCanceledException exception)
        {
            logger.LogWarning(exception, "Mushaf page {Page} timed out", pageNumber);
            return Problem(statusCode: 504, title: "The Mushaf archive timed out. Please retry.");
        }
        catch (HttpRequestException exception)
        {
            logger.LogWarning(exception, "Mushaf page {Page} upstream failure", pageNumber);
            return Problem(statusCode: 502, title: "The Mushaf archive is temporarily unavailable.");
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            logger.LogError(exception, "Mushaf page {Page} storage failure", pageNumber);
            return Problem(statusCode: 503, title: "Mushaf storage is temporarily unavailable.");
        }
    }
}

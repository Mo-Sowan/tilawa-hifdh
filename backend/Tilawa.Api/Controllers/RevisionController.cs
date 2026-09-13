using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tilawa.Api.DTOs;
using Tilawa.Api.Services;

namespace Tilawa.Api.Controllers;

/// <summary>
/// Surah progress, self-assessments and the aggregate progress summary for the
/// signed-in user.
/// </summary>
[ApiController]
[Route("api/v1/revision")]
[Authorize]
public sealed class RevisionController : ControllerBase
{
    private readonly IRevisionService _service;

    public RevisionController(IRevisionService service)
    {
        _service = service;
    }

    /// <summary>All 114 surahs with this user's progress against each.</summary>
    [HttpGet("surahs")]
    public async Task<ActionResult<IReadOnlyCollection<SurahRevisionDto>>> GetSurahs(
        CancellationToken cancellationToken)
    {
        return Ok(await _service.GetSurahsAsync(cancellationToken));
    }

    /// <summary>The surah most in need of revision, or 404 before any exists.</summary>
    [HttpGet("priority")]
    public async Task<ActionResult<SurahRevisionDto>> GetPrioritySurah(
        CancellationToken cancellationToken)
    {
        var result = await _service.GetPrioritySurahAsync(cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    /// <summary>Records a recall estimate and returns the updated surah list.</summary>
    [HttpPost("self-assessments")]
    public async Task<ActionResult<IReadOnlyCollection<SurahRevisionDto>>> AssessSurah(
        [FromBody] SelfAssessmentRequestDto request,
        CancellationToken cancellationToken)
    {
        try
        {
            return Ok(await _service.RecordSelfAssessmentAsync(request, cancellationToken));
        }
        catch (InvalidOperationException exception)
        {
            return BadRequest(exception.Message);
        }
    }

    /// <summary>XP, streak, mastery buckets and the activity calendar.</summary>
    [HttpGet("progress")]
    public async Task<ActionResult<ProgressSummaryDto>> GetProgress(
        CancellationToken cancellationToken)
    {
        return Ok(await _service.GetProgressAsync(cancellationToken));
    }
}

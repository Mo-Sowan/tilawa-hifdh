using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tilawa.Api.DTOs;
using Tilawa.Api.Services;

namespace Tilawa.Api.Controllers;

/// <summary>
/// History of the user's offline follow-along sessions.
/// </summary>
/// <remarks>
/// Recognition happens entirely on the device. Only the outcome — which ayat
/// were matched, for how long, with what confidence — is uploaded; audio never
/// leaves the phone.
/// </remarks>
[ApiController]
[Route("api/v1/recitation")]
[Authorize]
public sealed class RecitationController : ControllerBase
{
    private readonly IRevisionService _service;

    public RecitationController(IRevisionService service)
    {
        _service = service;
    }

    [HttpPost("sessions")]
    public async Task<ActionResult<RecitationSessionDto>> CreateSession(
        [FromBody] CreateRecitationSessionRequestDto request,
        CancellationToken cancellationToken)
    {
        try
        {
            return Ok(await _service.RecordRecitationSessionAsync(request, cancellationToken));
        }
        catch (InvalidOperationException exception)
        {
            return BadRequest(exception.Message);
        }
    }

    [HttpGet("sessions")]
    public async Task<ActionResult<IReadOnlyCollection<RecitationSessionDto>>> GetSessions(
        [FromQuery] int limit = 50,
        CancellationToken cancellationToken = default)
    {
        return Ok(await _service.GetRecitationSessionsAsync(limit, cancellationToken));
    }
}

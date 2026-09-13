using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tilawa.Api.DTOs;
using Tilawa.Api.Services;

namespace Tilawa.Api.Controllers;

/// <summary>
/// The signed-in user's revision plans.
/// </summary>
[ApiController]
[Route("api/v1/revision/plans")]
[Authorize]
public sealed class PlanController : ControllerBase
{
    private readonly IRevisionService _service;

    public PlanController(IRevisionService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<RevisionPlanDto>>> GetPlans(
        CancellationToken cancellationToken)
    {
        return Ok(await _service.GetPlansAsync(cancellationToken));
    }

    [HttpPost]
    public async Task<ActionResult<RevisionPlanDto>> CreatePlan(
        [FromBody] CreateRevisionPlanRequestDto request,
        CancellationToken cancellationToken)
    {
        var result = await _service.CreatePlanAsync(request, cancellationToken);
        return result is null
            ? BadRequest("A plan needs a name of 80 characters or fewer and 1-40 valid surah numbers.")
            : Ok(result);
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<RevisionPlanDto>> UpdatePlan(
        Guid id,
        [FromBody] UpdateRevisionPlanRequestDto request,
        CancellationToken cancellationToken)
    {
        var result = await _service.UpdatePlanAsync(id, request, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeletePlan(Guid id, CancellationToken cancellationToken)
    {
        return await _service.DeletePlanAsync(id, cancellationToken) ? NoContent() : NotFound();
    }
}

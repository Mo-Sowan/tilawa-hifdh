using Microsoft.Extensions.Options;
using Tilawa.Api.Services;

namespace Tilawa.Api.Infrastructure.Mushaf;

/// <summary>Opt-in, resumable warm-up that does not delay server startup.</summary>
public sealed class MushafCachePrewarmer(IMushafPageCache cache, IOptions<MushafCacheOptions> options,
    ILogger<MushafCachePrewarmer> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.PrewarmEnabled) return;
        await Task.Yield();
        var completed = 0;
        var failed = 0;
        await Parallel.ForEachAsync(Enumerable.Range(1, 604), new ParallelOptions
        {
            MaxDegreeOfParallelism = options.Value.PrewarmParallelism,
            CancellationToken = stoppingToken,
        }, async (page, token) =>
        {
            try
            {
                await cache.GetAsync(page, token);
                Interlocked.Increment(ref completed);
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested) { throw; }
            catch (Exception exception)
            {
                Interlocked.Increment(ref failed);
                logger.LogWarning(exception, "Prewarm failed for Mushaf page {Page}; a later request can retry", page);
            }
            // Throttle each worker, including failures, to avoid hammering the archive.
            await Task.Delay(options.Value.PrewarmDelayMilliseconds, token);
        });
        logger.LogInformation("Mushaf prewarm finished: {Completed} cached, {Failed} failed", completed, failed);
    }
}

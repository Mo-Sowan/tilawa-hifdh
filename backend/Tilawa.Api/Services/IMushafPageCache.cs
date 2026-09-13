namespace Tilawa.Api.Services;

/// <summary>Application boundary; controllers know nothing about HTTP downloads or cache writes.</summary>
public interface IMushafPageCache
{
    Task<CachedMushafPage> GetAsync(int pageNumber, CancellationToken cancellationToken = default);
}

public sealed record CachedMushafPage(string FullPath, string ContentType);

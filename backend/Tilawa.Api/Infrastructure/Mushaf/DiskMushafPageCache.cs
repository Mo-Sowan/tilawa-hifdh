using System.Buffers;
using Microsoft.Extensions.Options;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Formats.Webp;
using Tilawa.Api.Services;

namespace Tilawa.Api.Infrastructure.Mushaf;

/// <summary>Singleton: final files are published atomically after successful decoding and encoding.</summary>
public sealed class DiskMushafPageCache : IMushafPageCache, IDisposable
{
    public const string HttpClientName = "MushafArchive";
    private readonly IHttpClientFactory _clients;
    private readonly MushafCacheOptions _options;
    private readonly ILogger<DiskMushafPageCache> _logger;
    private readonly string _directory;
    // Fixed size prevents unbounded key growth and lock-removal races.
    private readonly SemaphoreSlim[] _pages = Enumerable.Range(0, 604).Select(_ => new SemaphoreSlim(1, 1)).ToArray();
    private readonly SemaphoreSlim _downloads;

    public DiskMushafPageCache(IHttpClientFactory clients, IHostEnvironment environment,
        IOptions<MushafCacheOptions> options, ILogger<DiskMushafPageCache> logger)
    {
        _clients = clients;
        _options = options.Value;
        _logger = logger;
        _directory = Path.GetFullPath(_options.DirectoryPath, environment.ContentRootPath);
        _downloads = new SemaphoreSlim(_options.MaxConcurrentDownloads, _options.MaxConcurrentDownloads);
    }

    public async Task<CachedMushafPage> GetAsync(int pageNumber, CancellationToken cancellationToken = default)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(pageNumber, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(pageNumber, 604);
        cancellationToken.ThrowIfCancellationRequested();
        if (Find(pageNumber) is { } hit) return hit;
        var gate = _pages[pageNumber - 1];
        await gate.WaitAsync(cancellationToken);
        try
        {
            if (Find(pageNumber) is { } cached) return cached;
            await _downloads.WaitAsync(cancellationToken);
            try { return await DownloadAsync(pageNumber, cancellationToken); }
            finally { _downloads.Release(); }
        }
        finally { gate.Release(); }
    }

    private CachedMushafPage? Find(int pageNumber)
    {
        foreach (var (extension, contentType) in new[] { ("webp", "image/webp"), ("png", "image/png") })
        {
            var path = Path.Combine(_directory, $"page_{pageNumber:D3}.{extension}");
            var info = new FileInfo(path);
            if (info.Exists && info.Length > 0) return new(path, contentType);
        }
        return null;
    }

    private async Task<CachedMushafPage> DownloadAsync(int pageNumber, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_directory);
        var id = Guid.NewGuid().ToString("N");
        var sourcePath = Path.Combine(_directory, $".{pageNumber:D3}.{id}.download");
        var tempPath = Path.Combine(_directory, $".{pageNumber:D3}.{id}.tmp");
        var extension = _options.UseWebP ? "webp" : "png";
        var finalPath = Path.Combine(_directory, $"page_{pageNumber:D3}.{extension}");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(_options.DownloadTimeoutSeconds));
        var token = timeout.Token;
        try
        {
            using var client = _clients.CreateClient(HttpClientName);
            // Preserve the existing archive's zero-based JPEG numbering.
            using var response = await client.GetAsync(
                $"{_options.UpstreamRoot.TrimEnd('/')}/{pageNumber - 1:D3}.jpg",
                HttpCompletionOption.ResponseHeadersRead, token);
            response.EnsureSuccessStatusCode();
            var limit = _options.MaxDownloadMegabytes * 1024L * 1024L;
            if (response.Content.Headers.ContentLength > limit)
                throw new HttpRequestException("Archive image exceeds configured byte limit.");
            await using (var source = await response.Content.ReadAsStreamAsync(token))
            await using (var target = new FileStream(sourcePath, FileMode.CreateNew, FileAccess.Write, FileShare.None,
                65536, FileOptions.Asynchronous | FileOptions.SequentialScan))
            {
                var buffer = ArrayPool<byte>.Shared.Rent(65536);
                try
                {
                    long total = 0;
                    int count;
                    while ((count = await source.ReadAsync(buffer.AsMemory(), token)) != 0)
                    {
                        total += count;
                        if (total > limit) throw new HttpRequestException("Archive image exceeds configured byte limit.");
                        await target.WriteAsync(buffer.AsMemory(0, count), token);
                    }
                    if (response.Content.Headers.ContentLength is long expected && total != expected)
                        throw new HttpRequestException("Archive image transfer was truncated.");
                }
                finally { ArrayPool<byte>.Shared.Return(buffer); }
            }
            try
            {
                var info = await Image.IdentifyAsync(sourcePath, token);
                if ((long)info.Width * info.Height > _options.MaxImageMegapixels * 1_000_000L)
                    throw new HttpRequestException("Archive image exceeds configured pixel limit.");
                using var image = await Image.LoadAsync(new DecoderOptions { MaxFrames = 1 }, sourcePath, token);
                IImageEncoder encoder = _options.UseWebP
                    ? new WebpEncoder { Quality = _options.WebPQuality }
                    : new PngEncoder();
                await image.SaveAsync(tempPath, encoder, token);
            }
            catch (Exception exception) when (exception is UnknownImageFormatException or InvalidImageContentException or NotSupportedException)
            {
                throw new HttpRequestException("Archive returned an invalid image.", exception);
            }
            token.ThrowIfCancellationRequested();
            // Same-directory rename: readers never observe partial files. Another process may win.
            // A zero-byte remnant is not a cache hit and can be repaired under the page lock.
            if (new FileInfo(finalPath) is { Exists: true, Length: 0 }) File.Delete(finalPath);
            try { File.Move(tempPath, finalPath, overwrite: false); }
            catch (IOException) when (new FileInfo(finalPath) is { Exists: true, Length: > 0 }) { }
            return new(finalPath, _options.UseWebP ? "image/webp" : "image/png");
        }
        finally
        {
            DeleteTemporary(sourcePath);
            DeleteTemporary(tempPath);
        }
    }

    private void DeleteTemporary(string path)
    {
        try { File.Delete(path); }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        { _logger.LogWarning(exception, "Could not remove temporary Mushaf file {Path}", path); }
    }

    public void Dispose()
    {
        foreach (var gate in _pages) gate.Dispose();
        _downloads.Dispose();
    }
}

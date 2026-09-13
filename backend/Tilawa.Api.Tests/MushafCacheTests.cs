using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using Tilawa.Api.Controllers;
using Tilawa.Api.Infrastructure.Mushaf;
using Tilawa.Api.Services;
using Xunit;

namespace Tilawa.Api.Tests;

public sealed class MushafCacheTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"mushaf-test-{Guid.NewGuid():N}");
    private string CacheDirectory => Path.Combine(_root, "Storage", "MushafCache");
    private static byte[] Jpeg()
    {
        using var image = new Image<Rgb24>(8, 8);
        using var stream = new MemoryStream();
        image.SaveAsJpeg(stream);
        return stream.ToArray();
    }

    private DiskMushafPageCache Create(Handler handler, Action<MushafCacheOptions>? configure = null)
    {
        var options = new MushafCacheOptions();
        configure?.Invoke(options);
        return new(new ClientFactory(handler), new EnvironmentStub { ContentRootPath = _root },
            Options.Create(options), NullLogger<DiskMushafPageCache>.Instance);
    }

    [Fact]
    public async Task ConcurrentMissesDownloadOnceAndSurviveServiceRestart()
    {
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var handler = new Handler(async (request, token) =>
        {
            Assert.EndsWith("/000.jpg", request.RequestUri!.AbsoluteUri);
            entered.SetResult();
            await release.Task.WaitAsync(token);
            return new(HttpStatusCode.OK) { Content = new ByteArrayContent(Jpeg()) };
        });
        using (var cache = Create(handler))
        {
            var requests = Enumerable.Range(0, 20).Select(_ => cache.GetAsync(1)).ToArray();
            await entered.Task.WaitAsync(TimeSpan.FromSeconds(5));
            Assert.False(File.Exists(Path.Combine(CacheDirectory, "page_001.webp")));
            release.SetResult();
            var results = await Task.WhenAll(requests);
            Assert.All(results, page => Assert.Equal(results[0], page));
            Assert.Equal("image/webp", results[0].ContentType);
            Assert.Equal("image/webp", (await Image.DetectFormatAsync(results[0].FullPath)).DefaultMimeType);
        }
        using var restarted = Create(handler);
        await restarted.GetAsync(1);
        Assert.Equal(1, handler.Calls);
        Assert.Single(Directory.GetFiles(CacheDirectory));
    }

    [Fact]
    public async Task DifferentPagesRespectGlobalDownloadLimit()
    {
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var handler = new Handler(async (_, token) =>
        {
            entered.TrySetResult();
            await release.Task.WaitAsync(token);
            return new(HttpStatusCode.OK) { Content = new ByteArrayContent(Jpeg()) };
        });
        using var cache = Create(handler, o => o.MaxConcurrentDownloads = 1);
        var first = cache.GetAsync(1);
        await entered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        var second = cache.GetAsync(2);
        Assert.Equal(1, handler.Calls);
        Assert.False(second.IsCompleted);
        release.SetResult();
        await Task.WhenAll(first, second).WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Equal(2, handler.Calls);
    }

    [Fact]
    public async Task TimeoutReleasesLockAndDoesNotPublishFile()
    {
        var handler = new Handler(async (_, token) =>
        {
            await Task.Delay(Timeout.Infinite, token);
            return new(HttpStatusCode.OK);
        });
        using var cache = Create(handler, o => o.DownloadTimeoutSeconds = 1);
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => cache.GetAsync(1));
        Assert.Empty(Directory.GetFiles(CacheDirectory));
        handler.Reply = (_, _) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        { Content = new ByteArrayContent(Jpeg()) });
        await cache.GetAsync(1).WaitAsync(TimeSpan.FromSeconds(5));
    }

    [Fact]
    public async Task FailedDecodeLeavesNoCacheAndNextRequestRetries()
    {
        var handler = new Handler((_, _) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        { Content = new ByteArrayContent("<html>upstream error</html>"u8.ToArray()) }));
        using var cache = Create(handler);
        await Assert.ThrowsAsync<HttpRequestException>(() => cache.GetAsync(1));
        Assert.Empty(Directory.GetFiles(CacheDirectory));
        handler.Reply = (_, _) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        { Content = new ByteArrayContent(Jpeg()) });
        await cache.GetAsync(1);
        Assert.Equal(2, handler.Calls);
    }

    [Fact]
    public async Task CancelledWaiterDoesNotCancelActiveDownload()
    {
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var handler = new Handler(async (_, token) =>
        {
            entered.SetResult();
            await release.Task.WaitAsync(token);
            return new(HttpStatusCode.OK) { Content = new ByteArrayContent(Jpeg()) };
        });
        using var cache = Create(handler);
        var owner = cache.GetAsync(1);
        await entered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        using var cancellation = new CancellationTokenSource();
        var waiter = cache.GetAsync(1, cancellation.Token);
        cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => waiter);
        release.SetResult();
        await owner;
        Assert.Equal(1, handler.Calls);
    }

    [Fact]
    public async Task CancelledDownloadReleasesLocksAndAllowsRetry()
    {
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var handler = new Handler(async (_, token) =>
        {
            entered.SetResult();
            await Task.Delay(Timeout.Infinite, token);
            return new(HttpStatusCode.OK);
        });
        using var cache = Create(handler);
        using var cancellation = new CancellationTokenSource();
        var request = cache.GetAsync(1, cancellation.Token);
        await entered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => request);
        Assert.Empty(Directory.GetFiles(CacheDirectory));
        handler.Reply = (_, _) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        { Content = new ByteArrayContent(Jpeg()) });
        await cache.GetAsync(1).WaitAsync(TimeSpan.FromSeconds(5));
    }

    [Fact]
    public async Task PngOptionUsesCorrectEncodingAndLastPageMapping()
    {
        var handler = new Handler((request, _) =>
        {
            Assert.EndsWith("/603.jpg", request.RequestUri!.AbsoluteUri);
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(Jpeg()) });
        });
        using var cache = Create(handler, o => o.UseWebP = false);
        var page = await cache.GetAsync(604);
        Assert.EndsWith("page_604.png", page.FullPath);
        Assert.Equal("PNG", (await Image.DetectFormatAsync(page.FullPath)).Name);
        await cache.GetAsync(604);
        Assert.Equal(1, handler.Calls);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(605)]
    public async Task InvalidPageNeverDownloads(int page)
    {
        var handler = new Handler((_, _) => throw new InvalidOperationException());
        using var cache = Create(handler);
        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() => cache.GetAsync(page));
        Assert.Equal(0, handler.Calls);
    }

    [Fact]
    public async Task ControllerUsesPhysicalFileAndImmutableHeadersOnlyForSuccess()
    {
        var cache = new StubCache(_ => Task.FromResult(new CachedMushafPage(Path.Combine(_root, "page_001.webp"), "image/webp")));
        var controller = Controller(cache);
        var result = Assert.IsType<PhysicalFileResult>(await controller.GetPageImage(1, default));
        Assert.True(result.EnableRangeProcessing);
        Assert.Equal("public, max-age=31536000, immutable", controller.Response.Headers.CacheControl);
        Assert.IsType<BadRequestObjectResult>(await controller.GetPageImage(0, default));
        Assert.Equal("no-store", controller.Response.Headers.CacheControl);
    }

    [Theory]
    [InlineData(502)]
    [InlineData(503)]
    [InlineData(504)]
    public async Task ControllerMapsErrorsWithoutCachingThem(int status)
    {
        Exception exception = status switch { 502 => new HttpRequestException(), 503 => new IOException(), _ => new OperationCanceledException() };
        var controller = Controller(new StubCache(_ => Task.FromException<CachedMushafPage>(exception)));
        var result = Assert.IsType<ObjectResult>(await controller.GetPageImage(1, default));
        Assert.Equal(status, result.StatusCode);
        Assert.Equal("no-store", controller.Response.Headers.CacheControl);
    }

    private static MushafController Controller(IMushafPageCache cache) => new(cache, NullLogger<MushafController>.Instance)
    { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() } };

    public void Dispose() { if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true); }

    private sealed class StubCache(Func<CancellationToken, Task<CachedMushafPage>> reply) : IMushafPageCache
    {
        public Task<CachedMushafPage> GetAsync(int pageNumber, CancellationToken cancellationToken = default) => reply(cancellationToken);
    }
    private sealed class ClientFactory(Handler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false) { Timeout = Timeout.InfiniteTimeSpan };
    }
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> reply) : HttpMessageHandler
    {
        public int Calls;
        public Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> Reply = reply;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Interlocked.Increment(ref Calls);
            return Reply(request, cancellationToken);
        }
    }
    private sealed class EnvironmentStub : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Testing";
        public string ApplicationName { get; set; } = "Testing";
        public string ContentRootPath { get; set; } = "";
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}

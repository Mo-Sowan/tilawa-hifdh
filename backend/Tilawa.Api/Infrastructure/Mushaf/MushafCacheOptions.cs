using System.ComponentModel.DataAnnotations;

namespace Tilawa.Api.Infrastructure.Mushaf;

public sealed class MushafCacheOptions
{
    public const string SectionName = "MushafCache";
    [Required] public string DirectoryPath { get; set; } = "Storage/MushafCache";
    [Url] public string UpstreamRoot { get; set; } = "https://archive.org/download/qalooon-jam";
    [Range(1, 16)] public int MaxConcurrentDownloads { get; set; } = 4;
    [Range(1, 600)] public int DownloadTimeoutSeconds { get; set; } = 90;
    [Range(1, 100)] public int MaxDownloadMegabytes { get; set; } = 20;
    [Range(1, 100)] public int MaxImageMegapixels { get; set; } = 40;
    public bool UseWebP { get; set; } = true;
    [Range(1, 100)] public int WebPQuality { get; set; } = 90;
    public bool PrewarmEnabled { get; set; }
    [Range(1, 8)] public int PrewarmParallelism { get; set; } = 2;
    [Range(100, 60000)] public int PrewarmDelayMilliseconds { get; set; } = 1000;
}

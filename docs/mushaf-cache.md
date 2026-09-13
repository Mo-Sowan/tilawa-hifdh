# Mushaf page cache

`GET /api/v1/mushaf/page/1` through `/604` now uses a singleton
`IMushafPageCache`. The controller handles HTTP semantics; the infrastructure
implementation handles Archive.org, encoding, disk storage, and concurrency.
This follows the existing single-project layout with a separate application
contract and infrastructure namespace rather than introducing empty projects.

The default cache is `Storage/MushafCache` relative to the API content root.
Mount this directory on persistent SSD storage in production, or configure
`MushafCache__DirectoryPath` with an absolute mount path. Grant the application
read/write access. Container-local ephemeral storage is not persistent.

Files are `page_001.webp` through `page_604.webp`. Existing PNG files with the
same naming scheme are also served. Cache hits perform no upstream calls or
encoding and use ASP.NET Core physical file streaming with range support.
Successful responses carry `Cache-Control: public, max-age=31536000, immutable`;
failures carry `no-store`. The endpoint URL remains compatible with the reader.

On a miss, one request per page downloads the existing zero-based JPEG URL
(`000.jpg` through `603.jpg`). Downloads stream into uniquely named temporary
files, with byte and pixel limits, before decoding and encoding genuine WebP.
The completed image is renamed within the cache directory so readers cannot
see a partially written final file. Temporary files are cleaned up on ordinary
failure or cancellation; after a process crash, abandoned `.tmp`/`.download`
files can be removed while the service is stopped. They are never cache hits.

There are at most four concurrent cold-page downloads/encodes by default.
Per-page locks and the global concurrency limit are shared with pre-warming.
Locks apply to one process. Multiple replicas should use separate local caches,
or add distributed coordination when sharing storage. Atomic publication still
protects complete files, but does not suppress downloads across processes.

Cancellation reaches lock waits, HTTP headers/body, file writes, and encoding.
A cancelled waiting caller cannot cancel the active downloader. If the active
downloader disconnects, its work is cancelled and the next caller can retry.
The 90-second download timeout includes transfer and encoding; time waiting for
capacity is governed by request cancellation. Upstream failure/invalid content
returns 502, timeout 504, and storage failure 503; no partial response is cached.

## Pre-warm all 604 pages

From the repository root:

```powershell
dotnet run --project backend/Tilawa.Api -- --MushafCache:PrewarmEnabled=true
```

The hosted service runs once per process startup, in the background. It resumes
by skipping cached pages. By default two workers wait one second between pages
(including failures), giving a maximum burst of two and at most roughly two
starts per second across workers. It shares the four-download limit with live
traffic. Failures are logged independently and the final log reports cached
and failed counts. Restart with the flag to retry missing pages. Ctrl+C cancels
the service. Remove the flag after pre-warming; it is disabled in appsettings.

For PNG output, append `--MushafCache:UseWebP=false`. WebP defaults to quality 90;
inspect fine Arabic marks before reducing quality. Savings depend on the source
image and chosen quality; a 70% reduction is not guaranteed. Encoding uses
SixLabors.ImageSharp 3.1.12; review its bundled license for your deployment.
Old `App_Data/MushafCache/*.jpg` files are untouched; they are not renamed to a
different format. Pre-warming populates the new cache.

## CDN and updates

The public cache header allows a reverse proxy/CDN to cache this public endpoint.
A CDN is not provisioned by this code. Configure it to cache only successful
image responses and forward requests to the API on a miss. Do not replace page
content at an immutable URL: change the URL version (and purge the CDN where
needed) if the edition or scans change. PNG/WebP configuration changes affect
new misses only; existing cached pages retain their format.

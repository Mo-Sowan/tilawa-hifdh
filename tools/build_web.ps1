<#
.SYNOPSIS
    Builds the Tilawa web app and optionally serves it.

.DESCRIPTION
    The web build runs the whole product UI in a browser. On-device recitation
    is the one part that needs the mobile or desktop build, unless you place the
    model at app/assets/model/fastconformer_full_mixed.onnx first.

    -AllowGuest adds a "Continue without an account" button, which is what makes
    the build explorable without a configured OAuth client and a running API.

.EXAMPLE
    ./tools/build_web.ps1 -AllowGuest -Serve

.EXAMPLE
    ./tools/build_web.ps1 -ApiBaseUrl "https://api.example.com" `
                          -GoogleServerClientId "1234.apps.googleusercontent.com"
#>
[CmdletBinding()]
param(
    [string]$ApiBaseUrl = "http://localhost:5188",
    [string]$GoogleServerClientId = "",
    [string]$GoogleClientId = "",
    [string]$AppleServiceId = "",
    [string]$AppleRedirectUri = "",
    [switch]$AllowGuest,
    [switch]$Serve,
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot "app"
if (-not (Test-Path $appDir)) {
    throw "Could not find the app directory at $appDir"
}

$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) { $flutter = "C:\Users\$env:USERNAME\develop\flutter\bin\flutter.bat" }
if (-not (Test-Path $flutter)) {
    throw "flutter was not found on PATH. Install it or edit this script."
}

$arguments = @("build", "web", "--release", "--no-wasm-dry-run")
$arguments += "--dart-define=API_BASE_URL=$ApiBaseUrl"
if ($AllowGuest)            { $arguments += "--dart-define=ALLOW_GUEST=true" }
if ($GoogleServerClientId)  { $arguments += "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleServerClientId" }
if ($GoogleClientId)        { $arguments += "--dart-define=GOOGLE_CLIENT_ID=$GoogleClientId" }
if ($AppleServiceId)        { $arguments += "--dart-define=APPLE_SERVICE_ID=$AppleServiceId" }
if ($AppleRedirectUri)      { $arguments += "--dart-define=APPLE_REDIRECT_URI=$AppleRedirectUri" }

Push-Location $appDir
try {
    Write-Host "flutter $($arguments -join ' ')" -ForegroundColor Cyan
    & $flutter @arguments
    if ($LASTEXITCODE -ne 0) { throw "flutter build web failed with exit code $LASTEXITCODE" }

    $output = Join-Path $appDir "build\web"
    Write-Host "Built $output" -ForegroundColor Green

    if ($Serve) {
        # Any static server works; Flutter web only needs the files served over
        # HTTP rather than opened from disk.
        Write-Host "Serving on http://localhost:$Port (Ctrl+C to stop)" -ForegroundColor Cyan
        python -m http.server $Port --directory $output
    }
}
finally {
    Pop-Location
}

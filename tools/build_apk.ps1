<#
.SYNOPSIS
    Builds an installable Tilawa APK.

.DESCRIPTION
    Wraps `flutter build apk` with the dart-defines the app expects, so the
    resulting APK talks to the right API and has working Google sign-in.

    Without -GoogleServerClientId the app still builds and the offline
    recitation works, but the sign-in screen will report that Google Sign-In is
    not configured.

.EXAMPLE
    ./tools/build_apk.ps1 -ApiBaseUrl "https://api.example.com" `
                          -GoogleServerClientId "1234.apps.googleusercontent.com"

.EXAMPLE
    # Split per ABI to roughly halve the download size.
    ./tools/build_apk.ps1 -SplitPerAbi
#>
[CmdletBinding()]
param(
    [string]$ApiBaseUrl = "http://10.0.2.2:5188",
    [string]$GoogleServerClientId = "",
    [string]$GoogleClientId = "",
    [string]$AppleServiceId = "",
    [string]$AppleRedirectUri = "",
    [string]$ModelUrl = "",
    [switch]$SplitPerAbi,
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

$appDir = Join-Path (Split-Path -Parent $PSScriptRoot) "app"
if (-not (Test-Path $appDir)) {
    throw "Could not find the app directory at $appDir"
}

$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) { $flutter = "C:\Users\$env:USERNAME\develop\flutter\bin\flutter.bat" }
if (-not (Test-Path $flutter)) {
    throw "flutter was not found on PATH. Install it or edit this script."
}

$arguments = @("build", "apk")
$arguments += if ($Debug) { "--debug" } else { "--release" }
if ($SplitPerAbi) { $arguments += "--split-per-abi" }

$arguments += "--dart-define=API_BASE_URL=$ApiBaseUrl"
if ($GoogleServerClientId) { $arguments += "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleServerClientId" }
if ($GoogleClientId)       { $arguments += "--dart-define=GOOGLE_CLIENT_ID=$GoogleClientId" }
if ($AppleServiceId)       { $arguments += "--dart-define=APPLE_SERVICE_ID=$AppleServiceId" }
if ($AppleRedirectUri)     { $arguments += "--dart-define=APPLE_REDIRECT_URI=$AppleRedirectUri" }
if ($ModelUrl)             { $arguments += "--dart-define=MODEL_URL=$ModelUrl" }

Push-Location $appDir
try {
    Write-Host "flutter $($arguments -join ' ')" -ForegroundColor Cyan
    & $flutter @arguments
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed with exit code $LASTEXITCODE" }

    $outputDir = Join-Path $appDir "build\app\outputs\flutter-apk"
    Get-ChildItem $outputDir -Filter "*.apk" |
        Select-Object Name, @{ Name = "SizeMB"; Expression = { [math]::Round($_.Length / 1MB, 1) } }, FullName |
        Format-Table -AutoSize
}
finally {
    Pop-Location
}

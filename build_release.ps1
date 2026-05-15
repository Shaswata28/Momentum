# ─── Momentum Release Build Script ───────────────────────────────────────────
# Usage: .\build_release.ps1
# Output: build\app\outputs\flutter-apk\Momentum.apk

$ErrorActionPreference = "Stop"

$apkDir    = "build\app\outputs\flutter-apk"
$srcName   = "app-release.apk"
$destName  = "Momentum.apk"
$src       = Join-Path $apkDir $srcName
$dest      = Join-Path $apkDir $destName

Write-Host ""
Write-Host "  Building Momentum (release)..." -ForegroundColor Cyan

flutter build apk --release

if (-not (Test-Path $src)) {
    Write-Host ""
    Write-Host "  ERROR: Expected APK not found at $src" -ForegroundColor Red
    exit 1
}

# Remove any existing Momentum.apk from a previous build
if (Test-Path $dest) { Remove-Item $dest -Force }

Rename-Item -Path $src -NewName $destName

$size = [math]::Round((Get-Item $dest).Length / 1MB, 1)

Write-Host ""
Write-Host "  Done! Output:" -ForegroundColor Green
Write-Host "  $dest  ($size MB)" -ForegroundColor White
Write-Host ""

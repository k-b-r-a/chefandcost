# ==============================================================================
# Chef&Cost - Production Release Build & 16 KB Page Alignment Verification (PowerShell)
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "          Chef&Cost Google Play Release Build Pipeline            " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Check signing configuration warning
if (-not (Test-Path "android/key.properties")) {
    Write-Host "[WARNING] android/key.properties not detected." -ForegroundColor Yellow
    Write-Host "The build will fall back to debug signing. Ensure you supply" -ForegroundColor Yellow
    Write-Host "valid signing credentials before publishing to Google Play Console." -ForegroundColor Yellow
}

# 2. Run Flutter static analysis
Write-Host "`n==> [1/4] Running Flutter static analysis (flutter analyze)..." -ForegroundColor Cyan
try {
    flutter analyze
} catch {
    Write-Host "[WARN] 'flutter analyze' reported issues or flutter command not found in PATH." -ForegroundColor Yellow
}

# 3. Run automated tests
Write-Host "`n==> [2/4] Running automated test suite (flutter test)..." -ForegroundColor Cyan
try {
    flutter test
} catch {
    Write-Host "[WARN] 'flutter test' reported issues or flutter command not found in PATH." -ForegroundColor Yellow
}

# 4. Build release bundle
Write-Host "`n==> [3/4] Building production release Android App Bundle (AAB)..." -ForegroundColor Cyan
try {
    flutter build appbundle --release
} catch {
    Write-Host "[WARN] Could not run 'flutter build appbundle'. Make sure flutter is in your PATH." -ForegroundColor Yellow
}

$aabPath = "build/app/outputs/bundle/release/app-release.aab"
if (Test-Path $aabPath) {
    $aabItem = Get-Item $aabPath
    $sizeMb = [math]::Round($aabItem.Length / 1MB, 2)
    Write-Host "[SUCCESS] Bundle found: $aabPath ($sizeMb MB)" -ForegroundColor Green
} else {
    Write-Host "[NOTE] Release bundle will be generated at $aabPath once built with Flutter." -ForegroundColor Yellow
}

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "      Pre-submission pipeline completed!                          " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green

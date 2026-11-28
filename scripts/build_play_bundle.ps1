# ==============================================================================
# Chef&Cost - Production Release Build & 16 KB Page Alignment Verification (PowerShell)
# ==============================================================================

param(
    [switch]$AllowDebugSignedRelease
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "          Chef&Cost Google Play Release Build Pipeline            " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Parse APP_VERSION from pubspec.yaml
$pubspecLine = Select-String -Path "pubspec.yaml" -Pattern '^\s*version:\s*(.+)$' | Select-Object -First 1
if (-not $pubspecLine) {
    throw "Could not parse 'version:' from pubspec.yaml"
}
$AppVersion = $pubspecLine.Matches[0].Groups[1].Value.Trim()
Write-Host "App Version: $AppVersion" -ForegroundColor Cyan

$allowDebug = $AllowDebugSignedRelease.IsPresent -or ($env:ALLOW_DEBUG_SIGNED_RELEASE -eq "true")
if (-not (Test-Path "android/key.properties")) {
    if ($allowDebug) {
        Write-Host "[WARNING] android/key.properties not detected. Using -PallowDebugSignedRelease=true for local R8 testing." -ForegroundColor Yellow
    } else {
        throw "Release build aborted: android/key.properties is missing. Configure android/key.properties or pass -AllowDebugSignedRelease for local R8 testing."
    }
}

# 1. Run Flutter static analysis
Write-Host "`n==> [1/4] Running Flutter static analysis (flutter analyze)..." -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed with exit code $LASTEXITCODE" }

# 2. Run automated tests
Write-Host "`n==> [2/4] Running automated test suite (flutter test)..." -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { throw "flutter test failed with exit code $LASTEXITCODE" }

# 3. Build obfuscated release bundle
Write-Host "`n==> [3/4] Building production release Android App Bundle (AAB)..." -ForegroundColor Cyan
$symbolsDir = "build/app/outputs/symbols"
if (Test-Path $symbolsDir) { Remove-Item -Recurse -Force $symbolsDir }

$buildArgs = @(
    "build", "appbundle", "--release",
    "--obfuscate",
    "--split-debug-info=$symbolsDir",
    "--dart-define=APP_VERSION=$AppVersion"
)
if ($allowDebug -and -not (Test-Path "android/key.properties")) {
    $buildArgs += "--android-project-arg=allowDebugSignedRelease=true"
}

& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed with exit code $LASTEXITCODE" }

$aabPath = "build/app/outputs/bundle/release/app-release.aab"
if (-not (Test-Path $aabPath)) {
    throw "Release bundle was not found at $aabPath"
}

$aabItem = Get-Item $aabPath
$sizeMb = [math]::Round($aabItem.Length / 1MB, 2)
Write-Host "[SUCCESS] Bundle generated: $aabPath ($sizeMb MB)" -ForegroundColor Green

# Archive release artifacts
$archiveDir = "build/release-artifacts/$AppVersion"
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
Copy-Item -Force $aabPath "$archiveDir/app-release.aab"
$mappingPath = "build/app/outputs/mapping/release/mapping.txt"
if (Test-Path $mappingPath) {
    Copy-Item -Force $mappingPath "$archiveDir/mapping.txt"
}
if (Test-Path $symbolsDir) {
    $archiveSymbols = "$archiveDir/symbols"
    if (Test-Path $archiveSymbols) { Remove-Item -Recurse -Force $archiveSymbols }
    Copy-Item -Recurse -Force $symbolsDir $archiveSymbols
}
Write-Host "[INFO] Archived release artifacts to $archiveDir" -ForegroundColor Cyan

# 4. Verify 16 KB ELF Page Alignment Compatibility
Write-Host "`n==> [4/4] Verifying 16 KB ELF memory page alignment on bundled native libraries..." -ForegroundColor Cyan
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) { $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $pythonCmd) {
    throw "Python is required to verify 16 KB ELF page alignment in $aabPath"
}

$pyScript = @'
import sys, zipfile, struct

aab_path = sys.argv[1]
found = 0
failed = 0

with zipfile.ZipFile(aab_path, 'r') as zf:
    for name in zf.namelist():
        if not (name.startswith('base/lib/') and name.endswith('.so')):
            continue
        found += 1
        data = zf.read(name)
        if not data.startswith(b'\x7fELF') or data[4] != 2:
            print(f"  [INFO] {name} -> SKIPPED (32-bit or non-ELF)")
            continue
        e_phoff = struct.unpack('<Q', data[32:40])[0]
        e_phentsize = struct.unpack('<H', data[54:56])[0]
        e_phnum = struct.unpack('<H', data[56:58])[0]
        all_aligned = True
        min_align = None
        for i in range(e_phnum):
            off = e_phoff + i * e_phentsize
            ph = data[off:off+56]
            if len(ph) < 56:
                break
            p_type = struct.unpack('<I', ph[0:4])[0]
            if p_type == 1:  # PT_LOAD
                p_align = struct.unpack('<Q', ph[48:56])[0]
                if min_align is None or p_align < min_align:
                    min_align = p_align
                if p_align < 16384:
                    all_aligned = False
        if all_aligned:
            print(f"  [PASS] {name} -> min p_align = {min_align} bytes (>= 16 KB)")
        else:
            print(f"  [FAIL] {name} -> min p_align = {min_align} bytes (< 16 KB)")
            failed += 1

if failed > 0:
    print(f"\n[ERROR] {failed} native library(ies) failed 16 KB page alignment!")
    sys.exit(1)
print(f"\n[SUCCESS] Verified {found} native libraries; all 64-bit libraries are 16 KB page-aligned.")
'@

$tempPy = [System.IO.Path]::GetTempFileName() + ".py"
Set-Content -Path $tempPy -Value $pyScript -Encoding UTF8
try {
    & $pythonCmd.Source $tempPy $aabPath
    if ($LASTEXITCODE -ne 0) {
        throw "16 KB ELF alignment verification failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Force $tempPy -ErrorAction SilentlyContinue
}

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "      Ready for Google Play Console: $archiveDir/app-release.aab  " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green

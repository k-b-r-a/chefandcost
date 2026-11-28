param(
    [string]$ReleaseNotes = "New testing release",
    [string]$Testers = "kbradevp@gmail.com",
    [switch]$SplitPerAbi
)

$ErrorActionPreference = "Stop"

$AppId = "1:194514517992:android:e049ba4d67978ff89bae5d"
$ProjectId = "chefycost"

$pubspecLine = Select-String -Path "pubspec.yaml" -Pattern '^\s*version:\s*(.+)$' | Select-Object -First 1
if (-not $pubspecLine) {
    throw "Could not parse 'version:' from pubspec.yaml"
}
$AppVersion = $pubspecLine.Matches[0].Groups[1].Value.Trim()

Write-Host "==> Running flutter analyze..." -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed" }

Write-Host "==> Running flutter test..." -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { throw "flutter test failed" }

Write-Host "==> Building obfuscated Flutter Release APK ($AppVersion)..." -ForegroundColor Cyan
$symbolsDir = "build/app/outputs/apk-symbols"
if (Test-Path $symbolsDir) { Remove-Item -Recurse -Force $symbolsDir }

$buildArgs = @(
    "build", "apk", "--release",
    "--obfuscate",
    "--split-debug-info=$symbolsDir",
    "--dart-define=APP_VERSION=$AppVersion"
)
if ($SplitPerAbi) {
    $buildArgs += "--split-per-abi"
}

& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }

$artifactDir = "build/release-artifacts/$AppVersion"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

if ($SplitPerAbi) {
    $apkPath = "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
    Copy-Item -Force "build/app/outputs/flutter-apk/app-*-release.apk" $artifactDir
} else {
    $apkPath = "build/app/outputs/flutter-apk/app-release.apk"
    Copy-Item -Force $apkPath "$artifactDir/ChefAndCost-$AppVersion-release.apk"
}

if (-not (Test-Path $apkPath)) {
    throw "APK not found at $apkPath"
}

Write-Host "==> Uploading and distributing to Firebase App Distribution..." -ForegroundColor Cyan
$fbArgs = @(
    "appdistribution:distribute", $apkPath,
    "--project", $ProjectId,
    "--app", $AppId,
    "--groups", "beta-testers",
    "--release-notes", $ReleaseNotes
)
if (-not [string]::IsNullOrWhiteSpace($Testers)) {
    $fbArgs += @("--testers", $Testers)
}

& firebase @fbArgs
if ($LASTEXITCODE -ne 0) { throw "firebase appdistribution:distribute failed" }

Write-Host "==> Distribution complete! Artifacts archived in $artifactDir" -ForegroundColor Green

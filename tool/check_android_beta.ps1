$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not (Test-Path "android\key.properties")) {
    throw "Signature absente. Lance d'abord .\tool\prepare_android_signing.ps1"
}

flutter pub get
flutter analyze
flutter test
npm --prefix functions run check
flutter build appbundle --release

$bundlePath = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path $bundlePath)) {
    throw "L'App Bundle release est introuvable."
}

$bundle = Get-Item $bundlePath
$hash = Get-FileHash -Path $bundlePath -Algorithm SHA256

Write-Host ""
Write-Host "BÊTA ANDROID PRÊTE"
Write-Host "Fichier : $($bundle.FullName)"
Write-Host "Taille  : $([Math]::Round($bundle.Length / 1MB, 2)) Mo"
Write-Host "SHA-256 : $($hash.Hash)"

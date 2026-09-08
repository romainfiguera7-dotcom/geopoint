param(
    [string]$Alias = "upload"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDirectory = Join-Path $projectRoot "android"
$keystorePath = Join-Path $androidDirectory "app\upload-keystore.jks"
$propertiesPath = Join-Path $androidDirectory "key.properties"

if (Test-Path $keystorePath) {
    throw "La clé existe déjà : $keystorePath. Elle n'a pas été remplacée."
}
if (Test-Path $propertiesPath) {
    throw "La configuration existe déjà : $propertiesPath. Elle n'a pas été remplacée."
}

$keytool = Get-Command keytool -ErrorAction Stop
$securePassword = Read-Host `
    "Choisis le mot de passe de la clé d'envoi (8 caractères minimum)" `
    -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)

try {
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if ($password.Length -lt 8) {
        throw "Le mot de passe doit contenir au moins 8 caractères."
    }
    if ($password -notmatch '^[\x21-\x7E]+$') {
        throw "Utilise uniquement des caractères simples, sans espace ni accent."
    }

    & $keytool.Source -genkeypair -v `
        -keystore $keystorePath `
        -storetype JKS `
        -storepass $password `
        -keypass $password `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -alias $Alias `
        -dname "CN=GeoPoint Upload, O=GeoPoint, C=FR"

    if ($LASTEXITCODE -ne 0) {
        throw "keytool n'a pas pu créer la clé d'envoi."
    }

    @(
        "storeFile=app/upload-keystore.jks"
        "storePassword=$password"
        "keyAlias=$Alias"
        "keyPassword=$password"
    ) | Set-Content -Path $propertiesPath -Encoding UTF8

    Write-Host ""
    Write-Host "Clé Android créée. Sauvegarde immédiatement ces deux fichiers :"
    Write-Host "- $keystorePath"
    Write-Host "- $propertiesPath"
    Write-Host ""
    Write-Host "Empreintes du certificat d'envoi :"
    & $keytool.Source -list -v `
        -keystore $keystorePath `
        -storepass $password `
        -alias $Alias |
        Select-String "SHA1:|SHA256:"
} finally {
    if ($pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    $password = $null
}

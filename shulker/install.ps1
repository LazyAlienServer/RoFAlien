$ErrorActionPreference = "Stop"

$release = "B0.15"
$coreUrl = "https://github.com/LiPolymer/ShulkerRDK/releases/download/$release/srdk.exe"
$asepriteUrl = "https://github.com/LiPolymer/ShulkerRDK/releases/download/$release/ShulkerRDK.Aseprite.dll"
$coreHash = "d78d89b955e37d979a879402bd766af3d2b60c7d25f9b7c44da07900c0f9f6e8"
$asepriteHash = "c84db27090410791e1a03ca7d70c51a3f01d9f5a9e304a5ad5551606ec238cb6"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$extensionDirectory = Join-Path $PSScriptRoot "extensions"
$corePath = Join-Path $repositoryRoot "srdk.exe"
$asepritePath = Join-Path $extensionDirectory "ShulkerRDK.Aseprite.dll"

New-Item -ItemType Directory -Force -Path $extensionDirectory | Out-Null

function Install-VerifiedAsset {
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $ExpectedHash
    )

    if (Test-Path -LiteralPath $Destination) {
        $existingHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Destination).Hash.ToLowerInvariant()
        if ($existingHash -eq $ExpectedHash) {
            Write-Host "Verified existing $(Split-Path -Leaf $Destination)"
            return
        }
    }

    $temporaryPath = "$Destination.download"
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $temporaryPath
        $downloadedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $temporaryPath).Hash.ToLowerInvariant()
        if ($downloadedHash -ne $ExpectedHash) {
            throw "SHA-256 mismatch for $Uri. Expected $ExpectedHash, received $downloadedHash."
        }
        Move-Item -Force -LiteralPath $temporaryPath -Destination $Destination
        Write-Host "Installed $(Split-Path -Leaf $Destination)"
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $temporaryPath
    }
}

Install-VerifiedAsset -Uri $coreUrl -Destination $corePath -ExpectedHash $coreHash
Install-VerifiedAsset -Uri $asepriteUrl -Destination $asepritePath -ExpectedHash $asepriteHash

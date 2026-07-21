$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "proj.json") | ConvertFrom-Json
$outputDirectory = Join-Path $repositoryRoot "build"
$archivePath = Join-Path $outputDirectory "$($project.ProjectName)_$($project.Version).zip"
$temporaryArchivePath = "$archivePath.tmp"
$sourcePath = Join-Path $repositoryRoot "src"
$cachePath = Join-Path $PSScriptRoot "local\cache\build"
$srdkPath = Join-Path $repositoryRoot "srdk.exe"
$verifierPath = Join-Path $PSScriptRoot "verify-build.ps1"

if (-not (Test-Path -LiteralPath $srdkPath)) {
    throw "ShulkerRDK is not installed. Run .\shulker\install.ps1 first."
}

function Remove-WithRetry {
    param([Parameter(Mandatory)] [string] $Path)

    foreach ($attempt in 1..20) {
        try {
            Remove-Item -Recurse -Force -ErrorAction Stop -LiteralPath $Path
            return
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            return
        }
        catch {
            if ($attempt -eq 20) { throw }
            Start-Sleep -Milliseconds 500
        }
    }
}

function Get-StableManifest {
    param([Parameter(Mandatory)] [string] $Root)

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    @(
        Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File | ForEach-Object {
            $stream = [System.IO.File]::Open($_.FullName, 'Open', 'Read', 'None')
            try {
                $sha = [System.Security.Cryptography.SHA256]::Create()
                try {
                    $hash = [Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant()
                }
                finally {
                    $sha.Dispose()
                }
            }
            finally {
                $stream.Dispose()
            }
            "$($_.FullName.Substring($resolvedRoot.Length + 1).Replace('\', '/'))|$($_.Length)|$hash"
        } | Sort-Object
    )
}

Remove-WithRetry -Path $cachePath
Remove-WithRetry -Path $temporaryArchivePath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

Push-Location $repositoryRoot
try {
    & $srdkPath build
}
finally {
    Pop-Location
}

$deadline = [DateTime]::UtcNow.AddSeconds(60)
$previousManifest = $null
$stableSamples = 0
$lastError = $null

while ([DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 500
    if (-not (Test-Path -LiteralPath $cachePath)) {
        continue
    }

    try {
        $manifest = Get-StableManifest -Root $cachePath
        if ($manifest.Count -eq 0) {
            continue
        }

        if ($null -ne $previousManifest -and -not (Compare-Object $previousManifest $manifest)) {
            $stableSamples++
        }
        else {
            $stableSamples = 0
            $previousManifest = $manifest
        }

        if ($stableSamples -lt 3) {
            continue
        }

        Remove-WithRetry -Path $temporaryArchivePath
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $cachePath,
            $temporaryArchivePath,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $false
        )
        $result = & $verifierPath -ArchivePath $temporaryArchivePath -SourcePath $sourcePath
        Move-Item -Force -LiteralPath $temporaryArchivePath -Destination $archivePath
        Remove-WithRetry -Path $cachePath
        Write-Host "Verified $($result.Files) files from $($result.AsepriteSources) Aseprite source files."
        Write-Host "Built $archivePath"
        exit 0
    }
    catch {
        $lastError = $_
        $stableSamples = 0
    }
}

Remove-WithRetry -Path $temporaryArchivePath
Remove-WithRetry -Path $archivePath
if ($lastError) {
    throw "ShulkerRDK build cache did not become valid and stable within 60 seconds. Last error: $($lastError.Exception.Message)"
}
throw "ShulkerRDK did not produce a build cache within 60 seconds."

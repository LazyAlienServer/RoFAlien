param(
    [Parameter(Mandatory)]
    [string] $ArchivePath,

    [Parameter(Mandatory)]
    [string] $SourcePath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceRoot = (Resolve-Path -LiteralPath $SourcePath).Path
$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ArchivePath).Path)
try {
    $entries = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
    $entryNames = @($entries.FullName)

    foreach ($required in @("LICENSE", "pack.mcmeta", "pack.png")) {
        if ($entryNames -notcontains $required) {
            throw "Build verification failed: missing required archive entry '$required'."
        }
    }

    $forbidden = @($entryNames | Where-Object {
        $_ -match '(?i)\.(aseprite|psd)$' -or
        $_ -match '(^|/)(shulker|build|\.idea)/'
    })
    if ($forbidden.Count -gt 0) {
        throw "Build verification failed: source/tool files leaked into the archive: $($forbidden -join ', ')."
    }

    $expectedStaticFiles = @(
        Get-ChildItem -LiteralPath $sourceRoot -Recurse -File |
            Where-Object { $_.Extension -notmatch '(?i)^\.aseprite$' } |
            ForEach-Object { $_.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/') }
    )
    $missingStaticFiles = @($expectedStaticFiles | Where-Object { $entryNames -notcontains $_ })
    if ($missingStaticFiles.Count -gt 0) {
        throw "Build verification failed: $($missingStaticFiles.Count) static source file(s) are missing, including '$($missingStaticFiles[0])'."
    }

    $asepriteFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter "*.aseprite")
    foreach ($asepriteFile in $asepriteFiles) {
        $relativeDirectory = $asepriteFile.DirectoryName.Substring($sourceRoot.Length).TrimStart('\').Replace('\', '/')
        $outputPrefix = if ($relativeDirectory) { "$relativeDirectory/$($asepriteFile.BaseName)" } else { $asepriteFile.BaseName }
        if (-not ($entryNames | Where-Object { $_ -like "$outputPrefix*.png" })) {
            throw "Build verification failed: no PNG output was generated for '$($asepriteFile.FullName)'."
        }
    }

    foreach ($entry in $entries) {
        $stream = $entry.Open()
        try {
            $buffer = New-Object byte[] 8192
            while ($stream.Read($buffer, 0, $buffer.Length) -gt 0) {}
        }
        finally {
            $stream.Dispose()
        }
    }

    [pscustomobject]@{
        Archive = (Resolve-Path -LiteralPath $ArchivePath).Path
        Files = $entries.Count
        StaticFiles = $expectedStaticFiles.Count
        AsepriteSources = $asepriteFiles.Count
    }
}
finally {
    $archive.Dispose()
}

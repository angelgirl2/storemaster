# Create a compact, source-focused copy of Store Master Pro for code review.
# This script does NOT delete or modify anything in the original project.
# Run it from PowerShell after extracting the project, ideally from the project root.

param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$OutputPath = (Join-Path $env:USERPROFILE 'Desktop\store_master_source.zip')
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd([char[]]@('\','/'))
if (-not (Test-Path -LiteralPath (Join-Path $root 'store_master_admin\pubspec.yaml')) -or
    -not (Test-Path -LiteralPath (Join-Path $root 'store_master_offline\pubspec.yaml'))) {
    throw "پوشه پروژه تشخیص داده نشد. اسکریپت را از ریشه‌ای اجرا کن که هر دو پوشه store_master_admin و store_master_offline داخل آن باشند."
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$excludedDirectoryNames = @(
    'build', '.dart_tool', '.gradle', '.idea', '.git', 'ephemeral',
    '.packages', '.pub-cache'
)
$excludedExactNames = @(
    '.env', '.env.test', '.env.prod', 'key.properties',
    '.flutter-plugins-dependencies'
)
$excludedExtensions = @('.jks', '.keystore', '.db', '.sqlite', '.sqlite3')

$files = Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
    $f = $_
    $relative = $f.FullName.Substring($root.Length).TrimStart([char[]]@('\','/'))
    $parts = $relative -split '[\\/]'
    $hasGeneratedFolder = $false
    foreach ($part in $parts) {
        if ($excludedDirectoryNames -contains $part) { $hasGeneratedFolder = $true; break }
    }
    if ($hasGeneratedFolder) { return $false }
    if ($excludedExactNames -contains $f.Name) { return $false }
    if ($excludedExtensions -contains $f.Extension.ToLowerInvariant()) { return $false }
    if ($f.Name -match '^hs_err_pid.*\.log$') { return $false }
    return $true
}

if (-not $files -or $files.Count -eq 0) { throw 'هیچ فایل سورسی برای افزودن به ZIP پیدا نشد.' }

$outFull = [System.IO.Path]::GetFullPath($OutputPath)
if ([System.IO.Path]::GetFullPath($root).Equals([System.IO.Path]::GetFullPath((Split-Path -Parent $outFull)), [System.StringComparison]::OrdinalIgnoreCase)) {
    # An output ZIP in the project root could get picked up on a later run; remove it from the file set.
    $files = @($files | Where-Object { $_.FullName -ne $outFull })
}
$outDir = Split-Path -Parent $outFull
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
if (Test-Path -LiteralPath $outFull) { Remove-Item -LiteralPath $outFull -Force }

$zipStream = [System.IO.File]::Open($outFull, [System.IO.FileMode]::CreateNew)
try {
    $zip = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        $done = 0
        foreach ($f in $files) {
            $relative = $f.FullName.Substring($root.Length).TrimStart([char[]]@('\','/'))
            $entryName = $relative -replace '\\','/'
            $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
            $sourceStream = [System.IO.File]::OpenRead($f.FullName)
            try {
                $entryStream = $entry.Open()
                try { $sourceStream.CopyTo($entryStream) }
                finally { $entryStream.Dispose() }
            }
            finally { $sourceStream.Dispose() }
            $done++
        }
    }
    finally { $zip.Dispose() }
}
finally { $zipStream.Dispose() }

$result = Get-Item -LiteralPath $outFull
Write-Host "\nZIP ساخته شد: $($result.FullName)" -ForegroundColor Green
Write-Host ("تعداد فایل‌ها: {0:N0}" -f $files.Count)
Write-Host ("حجم ZIP: {0:N1} MB" -f ($result.Length / 1MB))
Write-Host 'پوشه‌های خروجی build، cache و فایل‌های محرمانه امضای برنامه در این ZIP قرار نگرفتند؛ فایل‌های اصلی پروژه دست‌نخورده ماندند.'

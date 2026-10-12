param(
  [string]$Logo = "assets/images/logo.png",
  [string]$Out = "windows/runner/resources/app_icon.ico"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Logo)) {
  throw "Logo not found: $Logo"
}

New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null

if (Get-Command magick -ErrorAction SilentlyContinue) {
  magick $Logo -background none -resize 256x256 `
    -define icon:auto-resize=256,128,64,48,32,24,16 $Out
  Write-Host "Created $Out"
  exit 0
}

throw "ImageMagick (magick) was not found. Install it once, or generate app_icon.ico from assets/images/logo.png and place it at $Out."

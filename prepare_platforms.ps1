$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host '== Store Master platform setup ==' -ForegroundColor Cyan

Push-Location (Join-Path $root 'store_master_offline')
flutter create --platforms=android,windows --project-name store_master . --no-pub
Pop-Location

Push-Location (Join-Path $root 'store_master_admin')
flutter create --platforms=windows --project-name store_master_admin . --no-pub
Pop-Location

# Client Android package/namespace
$gradle = Join-Path $root 'store_master_offline/android/app/build.gradle'
$gradleKts = Join-Path $root 'store_master_offline/android/app/build.gradle.kts'
foreach ($file in @($gradle,$gradleKts)) {
  if (Test-Path $file) {
    $t = Get-Content $file -Raw
    $t = $t -replace 'com\.example\.store_master', 'com.angelgirlbrand.store_master'
    $t = $t -replace 'com\.example\.store_master_offline', 'com.angelgirlbrand.store_master'
    Set-Content $file $t
  }
}

# Ensure Android internet permission for API access.
$manifest = Join-Path $root 'store_master_offline/android/app/src/main/AndroidManifest.xml'
if (Test-Path $manifest) {
  $t = Get-Content $manifest -Raw
  if ($t -notmatch 'android.permission.INTERNET') {
    $t = $t -replace '<manifest([^>]*)>', '<manifest$1>\n    <uses-permission android:name="android.permission.INTERNET" />'
    Set-Content $manifest $t
  }
}

Write-Host 'Platforms generated: Android + Windows client, Windows admin.' -ForegroundColor Green
Write-Host 'Then run: flutter pub get in store_master_offline and store_master_admin.' -ForegroundColor Yellow

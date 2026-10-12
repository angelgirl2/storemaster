$ErrorActionPreference = "Stop"
$targets = @(
  "lib\services\license_manager_screen.dart",
  "lib\services\license_repository.dart"
)
foreach ($t in $targets) { if (Test-Path $t) { Remove-Item $t -Force; Write-Host "Removed $t" } }
$activation = "lib\screens\license\license_activation_screen.dart"
if (Test-Path $activation) {
  $text = Get-Content $activation -Raw -Encoding UTF8
  $text = $text -replace 'FilePicker\.pickFiles\(', 'FilePicker.platform.pickFiles('
  $text = $text -replace 'FilePicker\.saveFile\(', 'FilePicker.platform.saveFile('
  $text = $text -replace 'TextDirection\.ltr', 'ui.TextDirection.ltr'
  $text = $text -replace 'TextDirection\.rtl', 'ui.TextDirection.rtl'
  $text = $text -replace 'ui\.ui\.TextDirection', 'ui.TextDirection'
  $text = $text -replace "import 'package:flutter/services.dart';\r?\n", ''
  if ($text -notmatch "import 'dart:ui' as ui;") { $text = "import 'dart:ui' as ui;`r`n" + $text }
  Set-Content $activation $text -Encoding UTF8
}
flutter clean
flutter pub get
flutter analyze

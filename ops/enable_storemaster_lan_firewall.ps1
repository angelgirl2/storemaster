# اجرای یک‌باره روی Windows میزبان StoreMaster برای اجازهٔ همگام‌سازی محلی Wi‑Fi
# PowerShell را با Run as Administrator اجرا کنید.
$rules = @(
  @{Name='StoreMaster LAN Discovery UDP 38644'; Direction='Inbound'; Protocol='UDP'; LocalPort=38644},
  @{Name='StoreMaster LAN Sync TCP 38645'; Direction='Inbound'; Protocol='TCP'; LocalPort=38645}
)
foreach ($r in $rules) {
  if (-not (Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $r.Name -Direction $r.Direction -Protocol $r.Protocol -LocalPort $r.LocalPort -Action Allow -Profile Private
  }
}
Write-Host 'قوانین فایروال شبکه محلی StoreMaster فعال شدند.'

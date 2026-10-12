$ErrorActionPreference = 'Stop'

# StoreMaster Local Wi-Fi Sync firewall rules.
# Run PowerShell as Administrator on the Windows store computer.

$tcpName = 'StoreMaster LAN Sync TCP 38645'
$udpName = 'StoreMaster LAN Discovery UDP 38644'

Get-NetFirewallRule -DisplayName $tcpName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Get-NetFirewallRule -DisplayName $udpName -ErrorAction SilentlyContinue | Remove-NetFirewallRule

New-NetFirewallRule -DisplayName $tcpName `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 38645 `
  -Profile Private -Program Any | Out-Null

New-NetFirewallRule -DisplayName $udpName `
  -Direction Inbound -Action Allow -Protocol UDP -LocalPort 38644 `
  -Profile Private -Program Any | Out-Null

Write-Host 'StoreMaster LAN firewall rules created for Private networks.' -ForegroundColor Green

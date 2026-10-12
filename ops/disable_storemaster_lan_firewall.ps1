Remove-NetFirewallRule -DisplayName 'StoreMaster LAN Discovery UDP 38644' -ErrorAction SilentlyContinue
Remove-NetFirewallRule -DisplayName 'StoreMaster LAN Sync TCP 38645' -ErrorAction SilentlyContinue
Write-Host 'قوانین فایروال StoreMaster حذف شدند.'

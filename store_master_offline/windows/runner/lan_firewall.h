#pragma once

// One-time Windows Firewall bootstrap for StoreMaster LAN Sync.
// The app requests elevation only on the first run where the marker is absent.
// Subsequent launches skip the UAC prompt.
void EnsureStoreMasterLanFirewall();

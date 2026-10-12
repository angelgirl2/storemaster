#pragma once

// Requests a one-time Windows UAC elevation and configures the StoreMaster
// local LAN firewall rules. No PowerShell or manual command is required.
bool EnsureStoreMasterLanFirewall();

#include "lan_firewall.h"

#include <windows.h>
#include <shellapi.h>


namespace {
constexpr wchar_t kMarkerPath[] =
    L"Software\\StoreMaster\\LANSync";
constexpr wchar_t kMarkerName[] = L"FirewallConfigured";
constexpr wchar_t kCombinedArgs[] =
    L"/c \"netsh advfirewall firewall add rule name=StoreMaster-LAN-Sync dir=in action=allow protocol=TCP localport=38645 profile=any && "
    L"netsh advfirewall firewall add rule name=StoreMaster-LAN-Sync-UDP dir=in action=allow protocol=UDP localport=38644 profile=any\"";

bool IsConfigured() {
  HKEY key = nullptr;
  const LONG open = RegOpenKeyExW(HKEY_CURRENT_USER, kMarkerPath, 0,
                                  KEY_READ, &key);
  if (open != ERROR_SUCCESS) return false;

  DWORD value = 0;
  DWORD size = sizeof(value);
  DWORD type = 0;
  const LONG query = RegQueryValueExW(key, kMarkerName, nullptr, &type,
                                      reinterpret_cast<LPBYTE>(&value), &size);
  RegCloseKey(key);
  return query == ERROR_SUCCESS && type == REG_DWORD && value == 1;
}

void MarkConfigured() {
  HKEY key = nullptr;
  DWORD disposition = 0;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kMarkerPath, 0, nullptr, 0,
                      KEY_WRITE, nullptr, &key, &disposition) != ERROR_SUCCESS) {
    return;
  }
  const DWORD value = 1;
  RegSetValueExW(key, kMarkerName, 0, REG_DWORD,
                 reinterpret_cast<const BYTE*>(&value), sizeof(value));
  RegCloseKey(key);
}

bool RunElevatedNetsh(const wchar_t* arguments) {
  SHELLEXECUTEINFOW info{};
  info.cbSize = sizeof(info);
  info.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC;
  info.lpVerb = L"runas";
  info.lpFile = L"cmd.exe";
  info.lpParameters = arguments;
  info.nShow = SW_HIDE;

  if (!ShellExecuteExW(&info)) {
    return false;
  }

  if (info.hProcess == nullptr) {
    return true;
  }

  WaitForSingleObject(info.hProcess, 15000);
  DWORD exitCode = 1;
  GetExitCodeProcess(info.hProcess, &exitCode);
  CloseHandle(info.hProcess);
  return exitCode == 0;
}
}  // namespace

void EnsureStoreMasterLanFirewall() {
  if (IsConfigured()) return;

  // Keep the app usable even when the user declines elevation. LAN sync may
  // still work on networks whose Windows firewall already permits the ports.
  const bool configured = RunElevatedNetsh(kCombinedArgs);
  if (configured) {
    MarkConfigured();
  }
}

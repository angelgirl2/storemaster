#include "network_firewall.h"

#include <windows.h>
#include <shellapi.h>

#include <filesystem>
#include <chrono>
#include <string>

namespace {

std::filesystem::path MarkerPath() {
  wchar_t localAppData[MAX_PATH]{};
  const DWORD n = GetEnvironmentVariableW(L"LOCALAPPDATA", localAppData, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return {};
  }
  return std::filesystem::path(localAppData) / L"StoreMaster" / L"lan_firewall_v1.ok";
}

bool MarkerIsFresh() {
  const auto marker = MarkerPath();
  if (marker.empty() || !std::filesystem::exists(marker)) return false;
  std::error_code ec;
  const auto t = std::filesystem::last_write_time(marker, ec);
  if (ec) return false;
  // Recheck once per 30 days so rules can heal after an uninstall/reset.
  const auto age = std::filesystem::file_time_type::clock::now() - t;
  return age < std::chrono::hours(24 * 30);
}

bool RunElevatedNetsh(const std::wstring& parameters) {
  SHELLEXECUTEINFOW sei{};
  sei.cbSize = sizeof(sei);
  sei.fMask = SEE_MASK_NOCLOSEPROCESS;
  sei.lpVerb = L"runas";
  sei.lpFile = L"netsh.exe";
  sei.lpParameters = parameters.c_str();
  sei.nShow = SW_HIDE;

  if (!ShellExecuteExW(&sei)) {
    return false;
  }

  if (sei.hProcess) {
    WaitForSingleObject(sei.hProcess, 10000);
    DWORD exit_code = ERROR_GEN_FAILURE;
    GetExitCodeProcess(sei.hProcess, &exit_code);
    CloseHandle(sei.hProcess);
    return exit_code == ERROR_SUCCESS;
  }
  return false;
}

bool WriteMarker() {
  const auto marker = MarkerPath();
  if (marker.empty()) return false;
  std::error_code ec;
  std::filesystem::create_directories(marker.parent_path(), ec);
  if (ec) return false;
  HANDLE h = CreateFileW(marker.c_str(), GENERIC_WRITE, FILE_SHARE_READ,
                         nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (h == INVALID_HANDLE_VALUE) return false;
  const char ok[] = "ok\n";
  DWORD written = 0;
  WriteFile(h, ok, sizeof(ok) - 1, &written, nullptr);
  CloseHandle(h);
  return written == sizeof(ok) - 1;
}

}  // namespace

bool EnsureStoreMasterLanFirewall() {
  if (MarkerIsFresh()) return true;

  // Only Private-network traffic is allowed. This keeps StoreMaster LAN
  // discovery/sync off public Wi-Fi profiles.
  const bool tcp = RunElevatedNetsh(
      L"advfirewall firewall add rule name=\"StoreMaster LAN Sync TCP\" "
      L"dir=in action=allow protocol=TCP localport=38645 profile=private enable=yes");
  const bool udp = RunElevatedNetsh(
      L"advfirewall firewall add rule name=\"StoreMaster LAN Discovery UDP\" "
      L"dir=in action=allow protocol=UDP localport=38644 profile=private enable=yes");

  if (tcp && udp) {
    WriteMarker();
    return true;
  }

  return false;
}

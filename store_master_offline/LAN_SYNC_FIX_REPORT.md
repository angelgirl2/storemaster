# StoreMaster LAN Sync Fix

This build repairs Windows <-> Android local-Wi-Fi synchronization.

## Fixed
1. New SQLite installations now create `sync_flags`, `sync_outbox`, `local_sync_log` and all LAN triggers during `onCreate`.
2. Database version is 25 and existing installations rebuild LAN triggers during upgrade.
3. Windows TCP WebSocket hub stays available even if UDP discovery cannot bind.
4. Windows UDP uses `reusePort: false` for better cross-platform socket compatibility.
5. Android uses `ws://` LAN connections with Android cleartext traffic explicitly enabled.
6. Android keeps UDP broadcast discovery and adds a TCP fallback scan for the active private `/24` network when broadcast is blocked.
7. Shared license state is resent when it changes so Android can receive a newly activated shared license without reinstalling.
8. ViewModel reloads are queued when a LAN snapshot arrives while the initial SQLite load is still running.
9. A Windows Firewall helper was added at `tools/ENABLE_LAN_FIREWALL.bat`.

## LAN ports
- TCP 38645: actual WebSocket data sync
- UDP 38644: automatic discovery

## First Windows setup
Run `tools/ENABLE_LAN_FIREWALL.bat` once as Administrator on the Windows computer running StoreMaster.

Both devices must be connected to the same Wi-Fi/LAN, and the access point must allow device-to-device communication (AP/client isolation disabled).

## Verification
The source was statically inspected and the generated SQLite trigger pattern was executed successfully against SQLite in a representative test. Flutter/Dart SDK binaries are not installed in this execution environment, so a real `flutter analyze` / Android build could not be executed here.

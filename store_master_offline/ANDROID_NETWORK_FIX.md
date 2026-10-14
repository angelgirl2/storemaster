# StoreMaster Android LAN socket fix

The Android startup crash came from `RawDatagramSocket.bind(..., reusePort: true)` in `services/local_network_sync_service.dart`. Dart documents `reusePort` as an optional setting, and the Android Dart runtime does not support it; Android's socket implementation ignores/rejects that option. The Android discovery socket is now bound to an ephemeral port with `reuseAddress: false, reusePort: false`.

A second LAN bug was fixed at the same time: Windows now replies to the UDP discovery packet's **source port** (`dg.port`) rather than sending the discovery response to fixed port 38644.

The Android LAN service also no longer aborts the whole Flutter startup if LAN discovery cannot be created; it records `lan:error:...` and lets StoreMaster continue to open.

## AndroidManifest.xml

Ensure the Android app manifest contains:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Put it directly under `<manifest ...>` in `android/app/src/main/AndroidManifest.xml`.

For the current UDP broadcast design, do **not** add special privileged socket permissions.

## Windows firewall

On the Windows machine running StoreMaster, allow inbound UDP **38644** and TCP **38645** on the Private network profile.

## Expected flow

1. Android creates an ephemeral UDP discovery socket.
2. Android broadcasts a discovery packet to `255.255.255.255:38644`.
3. Windows receives it and replies to the Android packet's source IP + source port.
4. Android opens WebSocket `ws://<Windows-IP>:38645/ws`.


## Dashboard duplicate actions

The dashboard had two separate quick-action sections: the new permission-aware section and an older static section. This made destinations such as POS, products, stock, contacts, expenses and reports appear twice with different labels. The old static section has been removed. The remaining action builder also de-duplicates by route, so each destination is rendered only once.

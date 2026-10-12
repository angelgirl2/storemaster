import 'package:flutter/material.dart';

import '../services/local_network_sync_service.dart';

class LocalConnectionStatus extends StatelessWidget {
  const LocalConnectionStatus({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalNetworkSyncService.instance,
      builder: (context, _) {
        final service = LocalNetworkSyncService.instance;
        final online = service.isLocalOnline;
        return Tooltip(
          message: service.userFacingStatus,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                online ? Icons.wifi : Icons.wifi_off,
                size: compact ? 18 : 20,
              ),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(service.userFacingStatus),
              ],
            ],
          ),
        );
      },
    );
  }
}

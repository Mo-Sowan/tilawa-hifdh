import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/features/recitation/presentation/recitation_providers.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/auth_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/widgets/settings_tile.dart';

/// Server reachability plus a manual push of anything still queued locally.
class SyncTile extends ConsumerStatefulWidget {
  const SyncTile({super.key});

  @override
  ConsumerState<SyncTile> createState() => SyncTileState();
}

class SyncTileState extends ConsumerState<SyncTile> {
  bool _syncing = false;

  Future<void> _sync() async {
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (ref.read(authProvider).isGuest) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.syncUnavailableOffline)),
      );
      return;
    }

    setState(() => _syncing = true);
    try {
      final uploaded =
          await ref.read(recitationSessionRepositoryProvider).syncPending();
      ref.invalidate(apiHealthProvider);
      ref.invalidate(revisionOverviewProvider);
      ref.invalidate(progressSummaryProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(strings.syncUploaded(uploaded))),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(strings.syncFailed)));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final health = ref.watch(apiHealthProvider);

    return SettingsTile(
      icon: Icons.cloud_sync_outlined,
      title: strings.apiStatus,
      subtitle: health.when(
        data: (online) => online ? strings.online : strings.offline,
        loading: () => strings.checking,
        error: (_, __) => strings.offline,
      ),
      trailing: _syncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _sync,
              child: Text(strings.syncNow),
            ),
    );
  }
}

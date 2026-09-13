import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/leaderboard_provider.dart';
import 'package:tilawa/presentation/features/leaderboard/widgets/leaderboard_board.dart';

/// Where reciters see each other.
///
/// Two boards: everyone, and the people they have chosen to follow. The second
/// is the one that matters — a global ranking a beginner can never climb is
/// discouraging, while a handful of friends is a reason to keep going.
class LeaderboardView extends ConsumerStatefulWidget {
  const LeaderboardView({super.key});

  @override
  ConsumerState<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends ConsumerState<LeaderboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _promptForFriend() async {
    final strings = ref.read(appStringsProvider);
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.addFriend),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: strings.friendEmail,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(strings.addFriend),
          ),
        ],
      ),
    );

    controller.dispose();
    if (email == null || email.trim().isEmpty) return;

    try {
      await ref.read(addFriendProvider)(email.trim());
      messenger.showSnackBar(SnackBar(content: Text(strings.friendAdded)));
    } catch (error) {
      // The API answers the same way for an unknown address and for the
      // reciter's own, so this is the only message there is to give.
      debugPrint('Could not add a friend: $error');
      messenger.showSnackBar(SnackBar(content: Text(strings.friendNotFound)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.leaderboardTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: strings.leaderboardGlobal),
            Tab(text: strings.leaderboardFriends),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _promptForFriend,
            tooltip: strings.addFriend,
            icon: const Icon(Icons.person_add_alt_rounded),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          LeaderboardBoard(scope: LeaderboardScope.global),
          LeaderboardBoard(scope: LeaderboardScope.friends),
        ],
      ),
    );
  }
}

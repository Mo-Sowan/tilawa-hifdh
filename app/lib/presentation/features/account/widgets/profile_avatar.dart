import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';

/// The profile picture, with the tap that lets it be changed.
///
/// The picture is the reciter's own and never leaves the device: it is stored
/// with their settings, not uploaded.
class ProfileAvatar extends ConsumerStatefulWidget {
  const ProfileAvatar({super.key, required this.initial});

  final String initial;

  @override
  ConsumerState<ProfileAvatar> createState() => ProfileAvatarState();
}

class ProfileAvatarState extends ConsumerState<ProfileAvatar> {
  bool _busy = false;

  Future<void> _pick() async {
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Downsized here rather than after the fact: a full-resolution photo
        // is megabytes, and this is drawn at 92 logical pixels.
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await ref
          .read(appSettingsProvider.notifier)
          .setProfileImage(base64Encode(bytes));
    } catch (error) {
      debugPrint('Could not read the chosen photo: $error');
      messenger.showSnackBar(SnackBar(content: Text(strings.photoFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offerChoices() async {
    final strings = ref.read(appStringsProvider);
    final hasPhoto = ref.read(appSettingsProvider).profileImage != null;

    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.choosePhoto),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(strings.removePhoto),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
          ],
        ),
      ),
    );

    if (remove == null || !mounted) return;
    if (remove) {
      await ref.read(appSettingsProvider.notifier).setProfileImage(null);
    } else {
      await _pick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = ref.watch(appStringsProvider);
    final encoded = ref.watch(appSettingsProvider).profileImage;

    Uint8List? bytes;
    if (encoded != null) {
      try {
        bytes = base64Decode(encoded);
      } catch (error) {
        // A value written by an older build, or truncated storage.
        debugPrint('Discarding an unreadable profile picture: $error');
      }
    }

    return Semantics(
      button: true,
      label: strings.changePhoto,
      child: InkWell(
        onTap: _busy ? null : _offerChoices,
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: scheme.primary.withValues(alpha: 0.18),
              backgroundImage: bytes == null ? null : MemoryImage(bytes),
              child: bytes != null
                  ? null
                  : Text(
                      widget.initial,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.photo_camera_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/domain/entities/revision_section.dart';

/// Picks which part of the surah was revised.
///
/// A sheet rather than a row of chips: six preset ranges plus a custom one is
/// more than fits comfortably inline, and burying the custom case behind a
/// chip would have made the common answer and the precise answer look like
/// different features.
///
/// Returns the chosen value as a [RevisionSection] name or a `custom:from-to`
/// string, null if the reciter cleared it, and nothing at all if they dismissed
/// the sheet without deciding.
Future<String?> showSectionSheet(
  BuildContext context, {
  required AppStrings strings,
  required int ayahCount,
  required String? selected,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SectionSheet(
      strings: strings,
      ayahCount: ayahCount,
      selected: selected,
    ),
  );
}

class _SectionSheet extends StatefulWidget {
  const _SectionSheet({
    required this.strings,
    required this.ayahCount,
    required this.selected,
  });

  final AppStrings strings;
  final int ayahCount;
  final String? selected;

  @override
  State<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends State<_SectionSheet> {
  late final TextEditingController _from;
  late final TextEditingController _to;
  String? _error;

  @override
  void initState() {
    super.initState();
    final custom = RevisionSection.parseCustom(widget.selected);
    _from = TextEditingController(text: custom?.$1.toString() ?? '');
    _to = TextEditingController(text: custom?.$2.toString() ?? '');
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final from = int.tryParse(_from.text.trim());
    final to = int.tryParse(_to.text.trim());
    final strings = widget.strings;

    if (from == null || to == null) {
      setState(() => _error = strings.ayahRangeIncomplete);
      return;
    }
    if (from < 1 || to > widget.ayahCount || from > to) {
      setState(() => _error = strings.ayahRangeOutOfBounds(widget.ayahCount));
      return;
    }

    Navigator.of(context).pop(RevisionSection.customValue(from, to));
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.revisedSectionOptional,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            // A plain list rather than radios: the sheet closes on the tap, so
            // there is no moment where a selection sits waiting to be
            // confirmed, and nothing for a radio to represent.
            for (final section in RevisionSection.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(section.label(
                  isArabic: strings.isArabic,
                  ayahCount: widget.ayahCount,
                )),
                trailing: widget.selected == section.name
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(section.name);
                },
              ),
            const Divider(height: 24),
            Text(
              strings.customAyahRange,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _from,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: strings.fromAyah,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _to,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: strings.toAyah,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submitCustom,
                    child: Text(strings.useThisRange),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  // Recording nothing is a valid answer; it needs its own way
                  // out, not a second tap on whatever happens to be selected.
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(strings.clearSelection),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

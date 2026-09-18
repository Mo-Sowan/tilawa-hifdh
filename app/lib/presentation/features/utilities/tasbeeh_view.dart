import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';

class TasbeehView extends ConsumerStatefulWidget {
  const TasbeehView({super.key});

  @override
  ConsumerState<TasbeehView> createState() => _TasbeehViewState();
}

class _TasbeehViewState extends ConsumerState<TasbeehView> {
  int _count = 0;
  int _target = 33;

  void _tap() {
    if (_count >= _target) return;
    setState(() => _count++);
    if (_count == _target) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = ref.watch(appStringsProvider).isArabic;
    final reached = _count == _target;
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'عداد التسبيح' : 'Digital tasbeeh')),
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _target,
            decoration: InputDecoration(labelText: ar ? 'الهدف' : 'Target'),
            items: [33, 99, 100, 1000]
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              // A changed target starts a new round rather than silently counting old taps.
              setState(() {
                _target = value;
                _count = 0;
              });
            },
          ),
          const SizedBox(height: 32),
          Semantics(
            liveRegion: true,
            child: Text('$_count / $_target',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium),
          ),
          const SizedBox(height: 24),
          SizedBox(
              height: 240,
              child: FilledButton(
                key: const Key('tasbeeh-tap'),
                onPressed: reached ? null : _tap,
                style: FilledButton.styleFrom(shape: const CircleBorder()),
                child: Text(reached
                    ? (ar ? 'اكتمل الهدف' : 'Target reached')
                    : (ar ? 'اضغط للعدّ' : 'Tap to count')),
              )),
          const SizedBox(height: 24),
          LinearProgressIndicator(value: _count / _target),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => setState(() => _count = 0),
            icon: const Icon(Icons.restart_alt),
            label: Text(ar ? 'إعادة ضبط' : 'Reset'),
          ),
        ],
      )),
    );
  }
}

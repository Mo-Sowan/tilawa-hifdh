import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/data/repositories/recitation_session_repository.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/presentation/features/mushaf/mushaf_reader_view.dart';
import 'package:tilawa/presentation/features/surah_detail/surah_detail_view.dart';
import 'package:tilawa/recitation/service/recitation_engine.dart';
import 'package:tilawa/recitation/presentation/recitation_providers.dart';
import 'package:tilawa/recitation/presentation/widgets/memory_text.dart';
import 'package:tilawa/recitation/presentation/widgets/microphone_button.dart';
import 'package:tilawa/recitation/presentation/widgets/recitation_status_bar.dart';
import 'package:tilawa/recitation/presentation/widgets/recitation_timer_bar.dart';

/// Live recitation screen.
///
/// The reciter recites from memory; the on-device recogniser follows along and
/// reports which ayah they have reached and how far into it they are. Verse
/// text stays hidden by default — revealing it would turn memorisation
/// practice into reading — and can be shown when they want to check
/// themselves.
///
/// Finishing hands the session's duration and coverage to [SurahDetailView],
/// where the reciter records their own confidence, exactly as before.
class LiveRecitationView extends ConsumerStatefulWidget {
  const LiveRecitationView({required this.surah, super.key});

  final SurahRevision surah;

  @override
  ConsumerState<LiveRecitationView> createState() => _LiveRecitationViewState();
}

class _LiveRecitationViewState extends ConsumerState<LiveRecitationView>
    with TickerProviderStateMixin {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  bool _isPaused = false;
  bool _isFinishing = false;

  /// The Quran text is shown by default.
  ///
  /// Covering every word is the right tool for testing recall of something
  /// already memorised, but it makes the screen useless for anything else —
  /// a page of grey slabs is not a Quran. The eye in the title bar still
  /// covers the words for anyone who wants to be tested.
  bool _revealed = true;
  int _mushafOpenCount = 0;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _entranceController.forward();

    // Warm the model up front so tapping the microphone is instant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(recitationSessionProvider.notifier);
      session.setActiveSurah(widget.surah.number);
      unawaited(session.prepare().catchError((_) {}));
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _stopwatch.stop();
    _entranceController.dispose();
    unawaited(ref.read(recitationSessionProvider.notifier).stop());
    super.dispose();
  }

  void _togglePause() {
    setState(() {
      if (_isPaused) {
        _stopwatch.start();
        _isPaused = false;
      } else {
        _stopwatch.stop();
        _isPaused = true;
      }
    });
  }

  Future<void> _toggleListening() async {
    final notifier = ref.read(recitationSessionProvider.notifier);
    if (ref.read(recitationSessionProvider).isListening) {
      await notifier.stop();
    } else {
      await notifier.start();
    }
  }

  Future<void> _finishRecitation() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      _stopwatch.stop();
      final session = ref.read(recitationSessionProvider);
      await ref.read(recitationSessionProvider.notifier).stop();
      await _persistSession(session);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SurahDetailView(
            surah: widget.surah,
            preRecordedDuration: _stopwatch.elapsed,
            mushafOpenCount: _mushafOpenCount,
            versesRecited: session.covered.length,
            recitedRefs: session.covered.map((verse) => verse.ref).toList(),
            recitationConfidence: session.averageConfidence,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      if (!_isPaused) _stopwatch.start();
      final strings = ref.read(appStringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(strings.isArabic
              ? 'تعذر إنهاء الجلسة. أعد المحاولة.'
              : 'Could not finish the session. Please retry.')));
    }
  }

  /// Records the session locally and mirrors it to the API when reachable.
  /// A failure here must never block the assessment screen.
  Future<void> _persistSession(RecitationSessionState session) async {
    if (session.covered.isEmpty) return;

    try {
      await ref.read(recitationSessionRepositoryProvider).save(
            RecitationSessionRecord(
              id: '${DateTime.now().microsecondsSinceEpoch}-${widget.surah.number}',
              surahNumber: widget.surah.number,
              startedAt: session.startedAt ?? DateTime.now(),
              duration: _stopwatch.elapsed,
              versesMatched: session.covered.length,
              versesAttempted: widget.surah.ayahCount,
              averageConfidence: session.averageConfidence,
              coveredRefs: session.covered.map((v) => v.ref).toList(),
            ),
          );
    } catch (error) {
      debugPrint('Could not store the recitation session: $error');
    }
  }

  void _openMushaf() {
    setState(() => _mushafOpenCount++);
    final startPage = ref
            .read(quranTextIndexProvider)
            .valueOrNull
            ?.surahMeta(widget.surah.number)
            ?.startPage ??
        1;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MushafReaderView(initialPage: startPage),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final session = ref.watch(recitationSessionProvider);
    final engineStatus =
        ref.watch(recitationEngineStatusProvider).valueOrNull ??
            ref.watch(recitationEngineProvider).currentStatus;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFDF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          strings.isArabic ? 'مُراجعة من الحفظ' : 'Recite from Memory',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _revealed
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            tooltip: _revealed ? strings.revealHide : strings.revealShow,
            onPressed: () => setState(() => _revealed = !_revealed),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: strings.isArabic
                ? 'القراءة من مصحف الجماهيرية'
                : 'Read from Mushaf Al-Jamahiriya',
            onPressed: _openMushaf,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _entranceController,
        builder: (context, _) {
          return Opacity(
            opacity: _fadeIn.value,
            child: Transform.translate(
              offset: Offset(0, _slideUp.value),
              child: Column(
                children: [
                  RecitationTimerBar(
                    label: _formatDuration(_stopwatch.elapsed),
                    isPaused: _isPaused,
                    onToggle: _togglePause,
                    isArabic: strings.isArabic,
                    primary: primary,
                  ),
                  RecitationStatusBar(
                    status: engineStatus,
                    session: session,
                    isArabic: strings.isArabic,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: MemoryText(
                        surah: widget.surah,
                        session: session,
                        revealAll: _revealed,
                        fontSize: ref.watch(appSettingsProvider).quranFontSize,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      child: Row(
                        children: [
                          MicrophoneButton(
                            isListening: session.isListening,
                            enabled:
                                engineStatus.state != EngineState.unsupported &&
                                    (engineStatus.isReady ||
                                        engineStatus.state == EngineState.idle),
                            onPressed: _toggleListening,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  _isFinishing ? null : _finishRecitation,
                              icon: _isFinishing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.check_circle_rounded),
                              label: Text(
                                strings.isArabic
                                    ? 'إنهاء المراجعة'
                                    : 'Finish Recitation',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

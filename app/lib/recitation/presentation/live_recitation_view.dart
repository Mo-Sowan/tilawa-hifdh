import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/data/quran/quran_text_index.dart';
import 'package:tilawa/data/repositories/recitation_session_repository.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/presentation/views/mushaf_reader_view.dart';
import 'package:tilawa/presentation/views/surah_detail_view.dart';
import 'package:tilawa/recitation/engine/arabic_normalizer.dart';
import 'package:tilawa/recitation/service/recitation_engine.dart';
import 'package:tilawa/recitation/presentation/recitation_providers.dart';

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
                  _TimerBar(
                    label: _formatDuration(_stopwatch.elapsed),
                    isPaused: _isPaused,
                    onToggle: _togglePause,
                    isArabic: strings.isArabic,
                    primary: primary,
                  ),
                  _RecitationStatusBar(
                    status: engineStatus,
                    session: session,
                    isArabic: strings.isArabic,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _MemoryText(
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
                          _MicrophoneButton(
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

class _TimerBar extends StatelessWidget {
  const _TimerBar({
    required this.label,
    required this.isPaused,
    required this.onToggle,
    required this.isArabic,
    required this.primary,
  });

  final String label;
  final bool isPaused;
  final VoidCallback onToggle;
  final bool isArabic;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPaused ? Icons.pause_circle_filled : Icons.timer_rounded,
            color: primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 16),
          Material(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 20,
                      color: primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPaused
                          ? (isArabic ? 'استمر' : 'Resume')
                          : (isArabic ? 'إيقاف' : 'Pause'),
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Model download progress, listening state and errors in one strip.
class _RecitationStatusBar extends StatelessWidget {
  const _RecitationStatusBar({
    required this.status,
    required this.session,
    required this.isArabic,
  });

  final EngineStatus status;
  final RecitationSessionState session;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = session.error ??
        (status.state == EngineState.failed ? status.message : null);

    if (status.state == EngineState.unsupported) {
      // Nothing to retry: this build simply has no model to load.
      return _StatusStrip(
        icon: Icons.info_outline_rounded,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        label: status.message ??
            (isArabic
                ? 'التعرّف على التلاوة غير متاح في هذه النسخة.'
                : 'Recitation recognition is not available in this build.'),
      );
    }

    if (error != null) {
      return _StatusStrip(
        icon: Icons.error_outline_rounded,
        color: theme.colorScheme.error,
        label: error,
      );
    }

    if (status.state == EngineState.preparing) {
      final percent = status.progress;
      return _StatusStrip(
        icon: Icons.downloading_rounded,
        color: theme.colorScheme.primary,
        label: percent == null
            ? (status.message ??
                (isArabic ? 'جارٍ التحضير...' : 'Preparing...'))
            : '${status.message ?? (isArabic ? 'جارٍ التنزيل' : 'Downloading')}'
                ' ${(percent * 100).round()}%',
        progress: percent,
      );
    }

    if (session.isListening) {
      final covered = session.covered.length;
      return _StatusStrip(
        icon: Icons.graphic_eq_rounded,
        color: theme.colorScheme.primary,
        label: isArabic
            ? 'يستمع — $covered آية'
            : 'Listening — $covered ${covered == 1 ? 'ayah' : 'ayat'} matched',
      );
    }

    return _StatusStrip(
      icon: Icons.mic_none_rounded,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      label: isArabic
          ? 'اضغط على المِيكروفون لبدء المتابعة'
          : 'Tap the microphone to follow along',
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.icon,
    required this.color,
    required this.label,
    this.progress,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 4),
            ),
          ],
        ],
      ),
    );
  }
}

class _MicrophoneButton extends StatelessWidget {
  const _MicrophoneButton({
    required this.isListening,
    required this.enabled,
    required this.onPressed,
  });

  final bool isListening;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: isListening ? scheme.error : scheme.primary,
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          size: 26,
        ),
      ),
    );
  }
}

/// The surah's text, with every word covered until it is earned.
///
/// This is the memorisation surface, not a reader. The whole surah scrolls
/// continuously — no Mushaf page framing, no paging — and each word sits under
/// its own cover. A word uncovers when the recogniser hears the reciter say
/// it, so the page fills in behind them as they go and they can see at a
/// glance how far they got and where they stalled. A word can also be tapped
/// to peek at it, and the eye in the title bar uncovers everything at once.
///
/// Covers are drawn at the exact size of the word underneath, so uncovering
/// never reflows the text: what is revealed lands where the cover was.
class _MemoryText extends ConsumerStatefulWidget {
  const _MemoryText({
    required this.surah,
    required this.session,
    required this.revealAll,
    required this.fontSize,
  });

  final SurahRevision surah;
  final RecitationSessionState session;
  final bool revealAll;
  final double fontSize;

  @override
  ConsumerState<_MemoryText> createState() => _MemoryTextState();
}

class _MemoryTextState extends ConsumerState<_MemoryText> {
  final ScrollController _controller = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  /// Individual words the reciter has tapped to peek at, keyed `ayah:word`.
  final Set<String> _peekedWords = {};

  /// Whole ayahs uncovered by tapping their marker.
  final Set<int> _peekedAyahs = {};

  int? _lastFollowedAyah;

  @override
  void didUpdateWidget(_MemoryText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.session.current;
    if (current == null ||
        current.surah != widget.surah.number ||
        current.ayah == _lastFollowedAyah) {
      return;
    }
    // The recogniser moved on; bring the new ayah into view.
    _lastFollowedAyah = current.ayah;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollTo(current.ayah));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollTo(int ayah) {
    final context = _ayahKeys[ayah]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.25,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final ayahsAsync = ref.watch(quranSurahProvider(widget.surah.number));

    return ayahsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _TextPageMessage(message: '$error'),
      data: (ayahs) {
        if (ayahs.isEmpty) {
          return _TextPageMessage(message: strings.surahTextUnavailable);
        }

        // Ayahs already committed this session are uncovered in full.
        final recited = <int>{
          for (final verse in widget.session.covered)
            if (verse.surah == widget.surah.number) verse.ayah,
        };
        final current = widget.session.current;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _controller,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: ayahs.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _SurahHeading(
                      name: ayahs.first.surahName,
                      ayahCount: ayahs.length,
                      // Al-Fatiha prints the basmala as its first ayah and
                      // At-Tawba has none, so neither needs one added.
                      showBasmala:
                          widget.surah.number != 1 && widget.surah.number != 9,
                      hint: widget.revealAll ? null : strings.tapWordToPeek,
                      fontSize: widget.fontSize,
                    );
                  }

                  final ayah = ayahs[index - 1];
                  return _AyahBlock(
                    key: _ayahKeys.putIfAbsent(ayah.ayah, GlobalKey.new),
                    ayah: ayah,
                    fontSize: widget.fontSize,
                    isCurrent: current?.surah == ayah.surah &&
                        current?.ayah == ayah.ayah,
                    wordIndex: widget.session.wordIndex,
                    totalWords: widget.session.totalWords,
                    revealAll: widget.revealAll ||
                        recited.contains(ayah.ayah) ||
                        _peekedAyahs.contains(ayah.ayah),
                    peekedWords: _peekedWords,
                    onPeekWord: (wordIndex) => setState(
                      () => _peekedWords.add('${ayah.ayah}:$wordIndex'),
                    ),
                    onPeekAyah: () =>
                        setState(() => _peekedAyahs.add(ayah.ayah)),
                  );
                },
              ),
            ),
            _PositionBar(session: widget.session, strings: strings),
          ],
        );
      },
    );
  }
}

class _TextPageMessage extends StatelessWidget {
  const _TextPageMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// Surah name, length, and the basmala where the Mushaf prints one.
class _SurahHeading extends StatelessWidget {
  const _SurahHeading({
    required this.name,
    required this.ayahCount,
    required this.showBasmala,
    required this.hint,
    required this.fontSize,
  });

  final String name;
  final int ayahCount;
  final bool showBasmala;
  final String? hint;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.5);

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: AppTheme.arabicText(size: 26, color: scheme.onSurface),
        ),
        if (showBasmala)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.quranText(
                size: fontSize * 0.85,
                color: scheme.primary.withValues(alpha: 0.85),
              ),
            ),
          ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hint!,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        Divider(
          height: 20,
          color: scheme.onSurface.withValues(alpha: 0.10),
        ),
      ],
    );
  }
}

/// One ayah, word by word, so each word can be covered on its own.
///
/// The Uthmani text also carries standalone pause and hizb marks, which are
/// printed in the Mushaf but are not words anyone recites. They are never
/// covered, and — as in the recogniser, which works from the phoneme text and
/// so never sees them — they are not counted when working out how far into the
/// ayah the reciter has got.
class _AyahBlock extends StatelessWidget {
  const _AyahBlock({
    required this.ayah,
    required this.fontSize,
    required this.isCurrent,
    required this.wordIndex,
    required this.totalWords,
    required this.revealAll,
    required this.peekedWords,
    required this.onPeekWord,
    required this.onPeekAyah,
    super.key,
  });

  final QuranAyah ayah;
  final double fontSize;

  /// Whether the recogniser believes this is the ayah being recited.
  final bool isCurrent;

  /// How far into the ayah the recogniser has got, and out of how many words,
  /// both counted the recogniser's way.
  final int wordIndex;
  final int totalWords;

  final bool revealAll;
  final Set<String> peekedWords;
  final ValueChanged<int> onPeekWord;
  final VoidCallback onPeekAyah;

  static const List<String> _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  /// The Mushaf's end-of-ayah medallion: U+06DD, which Amiri Quran draws as
  /// the ornament, with the number set inside it in Arabic-Indic digits.
  static String _ayahMarker(int value) =>
      '۝${value.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join()}';

  /// A token is a word if anything survives the normalization the recogniser
  /// applies; a lone pause mark normalizes away to nothing.
  static bool _isWord(String token) => normalizeArabic(token).isNotEmpty;

  /// How many of this ayah's printed words are uncovered.
  ///
  /// The two counts agree for all but a couple of hundred verses, where the
  /// recogniser's text splits a token this one does not; there the position is
  /// scaled across rather than trusting an index that means something slightly
  /// different in each.
  int _wordsReached(int printedWords) {
    if (!isCurrent || printedWords == 0) return 0;
    if (totalWords == 0 || totalWords == printedWords) return wordIndex;
    return (wordIndex * printedWords / totalWords)
        .round()
        .clamp(0, printedWords);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = splitWords(ayah.textUthmani);
    final reached = _wordsReached(tokens.where(_isWord).length);
    final style = AppTheme.quranText(size: fontSize, color: scheme.onSurface);

    var ordinal = 0;
    final words = <Widget>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (!_isWord(token)) {
        words.add(
          Text(
            token,
            textDirection: TextDirection.rtl,
            style: style.copyWith(color: scheme.primary.withValues(alpha: 0.6)),
          ),
        );
        continue;
      }
      final spoken = ordinal < reached;
      words.add(
        _MaskedWord(
          word: token,
          style: style,
          visible:
              revealAll || spoken || peekedWords.contains('${ayah.ayah}:$i'),
          isSpoken: spoken,
          onPeek: () => onPeekWord(i),
        ),
      );
      ordinal++;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? scheme.primary.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        // Covers are as tall as the line box, so wrapped runs need room of
        // their own or the slabs of one run sit on top of the next.
        runSpacing: 8,
        children: [
          ...words,
          GestureDetector(
            onTap: onPeekAyah,
            child: Text(
              _ayahMarker(ayah.ayah),
              textDirection: TextDirection.rtl,
              style: style.copyWith(color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One word under a cover the size of the word.
///
/// The word is always laid out; hiding it only makes its glyphs transparent
/// and paints a slab over the space they occupy. That is what keeps the line
/// breaks identical whether the text is covered or not.
class _MaskedWord extends StatelessWidget {
  const _MaskedWord({
    required this.word,
    required this.style,
    required this.visible,
    required this.isSpoken,
    required this.onPeek,
  });

  final String word;
  final TextStyle style;
  final bool visible;

  /// Uncovered because the recogniser heard it, rather than by a tap.
  final bool isSpoken;

  final VoidCallback onPeek;

  static const Duration _fade = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverColor = scheme.onSurface.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: visible ? null : onPeek,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _fade,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: visible ? Colors.transparent : coverColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: AnimatedDefaultTextStyle(
          duration: _fade,
          curve: Curves.easeOut,
          style: style.copyWith(
            color: visible
                ? (isSpoken ? scheme.primary : style.color)
                : Colors.transparent,
          ),
          child: Text(word, textDirection: TextDirection.rtl),
        ),
      ),
    );
  }
}

/// Where the reciter is and how far into the ayah, in one strip.
class _PositionBar extends StatelessWidget {
  const _PositionBar({required this.session, required this.strings});

  final RecitationSessionState session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final current = session.current;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: session.verseProgress,
              minHeight: 4,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            current == null
                ? strings.reciteFromMemoryHint
                : '${strings.ayahPosition(current.surah, current.ayah)}'
                    ' · ${strings.ayatThisSession(session.covered.length)}',
            style: TextStyle(
              fontSize: 12,
              color: current == null ? muted : scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

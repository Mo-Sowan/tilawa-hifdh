import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/domain/entities/qibla.dart';
import 'package:tilawa/services/qibla_service.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/utilities/widgets/qibla_dial.dart';

class QiblaView extends ConsumerStatefulWidget {
  const QiblaView({super.key});
  @override
  ConsumerState<QiblaView> createState() => _QiblaViewState();
}

class _QiblaViewState extends ConsumerState<QiblaView>
    with WidgetsBindingObserver {
  StreamSubscription<double?>? _subscription;
  Timer? _sensorTimer;
  double? _bearing;
  double? _heading;
  QiblaFailure? _failure;
  bool _sensorMissing = false;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) unawaited(_start());
    if (state == AppLifecycleState.paused) {
      _subscription?.pause();
      _sensorTimer?.cancel();
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    _sensorTimer?.cancel();
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = true;
      _failure = null;
      _bearing = null;
      _heading = null;
      _sensorMissing = false;
    });
    final service = ref.read(qiblaServiceProvider);
    try {
      final bearing = await service.bearing();
      if (!mounted || generation != _generation) return;
      setState(() {
        _bearing = bearing;
        _loading = false;
      });
      void missing() {
        if (mounted && generation == _generation) {
          setState(() => _sensorMissing = true);
        }
      }

      _sensorTimer = Timer(const Duration(seconds: 5), missing);
      _subscription = service.headings.listen((heading) {
        if (!mounted || generation != _generation) return;
        if (heading == null || !heading.isFinite) {
          missing();
          return;
        }
        _sensorTimer?.cancel();
        setState(() {
          _heading = smoothCompassHeading(_heading, heading);
          _sensorMissing = false;
        });
      }, onError: (Object _) => missing(), onDone: missing);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failure = error is QiblaFailure ? error : QiblaFailure.unavailable;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _sensorTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = ref.watch(appStringsProvider).isArabic;
    final message = switch (_failure) {
      QiblaFailure.servicesOff => ar
          ? 'خدمات الموقع متوقفة. فعّلها ثم أعد المحاولة.'
          : 'Location services are off. Enable them and retry.',
      QiblaFailure.denied => ar
          ? 'لم يُسمح بالوصول للموقع. نحتاجه لحساب الاتجاه.'
          : 'Location permission was denied. It is needed to calculate the bearing.',
      QiblaFailure.deniedForever => ar
          ? 'فعّل إذن الموقع من إعدادات التطبيق.'
          : 'Allow location access in app settings.',
      QiblaFailure.unavailable => ar
          ? 'تعذر تحديد الموقع. أعد المحاولة.'
          : 'Could not determine your location. Please retry.',
      null => '',
    };
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'اتجاه القبلة' : 'Qibla compass')),
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_failure != null) ...[
            Text(message),
            if (_failure == QiblaFailure.servicesOff ||
                _failure == QiblaFailure.deniedForever)
              TextButton(
                  onPressed: () async {
                    final service = ref.read(qiblaServiceProvider);
                    final opened = _failure == QiblaFailure.servicesOff
                        ? await service.openLocationSettings()
                        : await service.openAppSettings();
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ar
                              ? 'افتح إعدادات الموقع على جهازك يدويًا.'
                              : 'Open your device location settings manually.')));
                    }
                  },
                  child: Text(ar ? 'فتح الإعدادات' : 'Open settings')),
          ],
          if (_bearing != null) ...[
            Text('${_bearing!.toStringAsFixed(1)}°',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium),
            Text(
                ar
                    ? 'من الشمال الحقيقي باتجاه عقارب الساعة'
                    : 'Clockwise from true north',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (_heading != null && !_sensorMissing)
              Center(
                  child: AnimatedRotation(
                turns: (_bearing! - _heading!) / 360,
                duration: const Duration(milliseconds: 180),
                child: CustomPaint(
                    size: const Size(260, 260),
                    painter: QiblaDial(Theme.of(context).colorScheme.primary)),
              )),
            const SizedBox(height: 24),
            Text(
                _sensorMissing
                    ? (ar
                        ? 'البوصلة غير متاحة هنا. استخدم الاتجاه الرقمي مع بوصلة خارجية.'
                        : 'Compass unavailable here. Use the numeric bearing with an external compass.')
                    : (ar
                        ? 'ضع الهاتف أفقيًا بعيدًا عن المعادن. حرّكه بشكل 8 لمعايرة البوصلة. اتجاه المستشعر تقريبي.'
                        : 'Hold the phone flat, away from metal. Move it in a figure eight to calibrate. The sensor direction is approximate.'),
                textAlign: TextAlign.center),
          ],
          if (!_loading)
            TextButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: Text(ar ? 'إعادة المحاولة' : 'Retry')),
        ],
      )),
    );
  }
}

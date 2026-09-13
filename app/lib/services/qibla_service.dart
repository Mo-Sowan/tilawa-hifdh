import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:tilawa/domain/entities/qibla.dart';

enum QiblaFailure { servicesOff, denied, deniedForever, unavailable }

class QiblaService {
  Stream<double?> get headings => kIsWeb
      ? const Stream.empty()
      : (FlutterCompass.events?.map((event) => event.heading) ??
          const Stream.empty());

  Future<double> bearing() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw QiblaFailure.servicesOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw QiblaFailure.deniedForever;
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw QiblaFailure.denied;
    }
    final location = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20)));
    return qiblaBearing(location.latitude, location.longitude);
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

final qiblaServiceProvider = Provider<QiblaService>((ref) => QiblaService());

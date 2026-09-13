import 'dart:math' as math;

/// Initial great-circle bearing clockwise from true north, in degrees.
double qiblaBearing(double latitude, double longitude) {
  if (!latitude.isFinite ||
      latitude.abs() > 90 ||
      !longitude.isFinite ||
      longitude.abs() > 180) {
    throw ArgumentError(
        'Coordinates must be finite and within geographic bounds.');
  }
  const radians = math.pi / 180;
  final start = latitude * radians;
  const destination = 21.4225 * radians;
  final delta = (39.8262 - longitude) * radians;
  final y = math.sin(delta) * math.cos(destination);
  final x = math.cos(start) * math.sin(destination) -
      math.sin(start) * math.cos(destination) * math.cos(delta);
  if (x.abs() < 1e-12 && y.abs() < 1e-12) {
    throw ArgumentError(
        'Bearing is undefined at the destination or its antipode.');
  }
  return (math.atan2(y, x) / radians + 360) % 360;
}

/// Keeps an unwrapped angle so both filtering and animation take the short way across north.
double smoothCompassHeading(double? previous, double heading,
    {double alpha = .15}) {
  if (!heading.isFinite ||
      (previous != null && !previous.isFinite) ||
      !alpha.isFinite ||
      alpha <= 0 ||
      alpha > 1) {
    throw ArgumentError('Invalid heading or filter weight.');
  }
  if (previous == null) return heading % 360;
  final delta = (heading - previous + 540) % 360 - 180;
  return previous + alpha * delta;
}

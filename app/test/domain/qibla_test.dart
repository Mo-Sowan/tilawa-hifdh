import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/domain/entities/qibla.dart';

void main() {
  test('great-circle bearings from Cairo and London', () {
    expect(qiblaBearing(30.0444, 31.2357), closeTo(136, 1));
    expect(qiblaBearing(51.5074, -.1278), closeTo(119, 1));
  });
  test('bearings remain normalized in both hemispheres', () {
    for (final point in [
      (0.0, 0.0),
      (-33.86, 151.2),
      (40.7, -74.0),
      (89.0, 179.0)
    ]) {
      expect(qiblaBearing(point.$1, point.$2), inInclusiveRange(0, 359.999999));
    }
  });
  test('invalid coordinates and undefined destination are rejected', () {
    expect(() => qiblaBearing(91, 0), throwsArgumentError);
    expect(() => qiblaBearing(0, double.nan), throwsArgumentError);
    expect(() => qiblaBearing(21.4225, 39.8262), throwsArgumentError);
  });
  test('low-pass filter follows the shortest arc across north', () {
    expect(smoothCompassHeading(359, 1, alpha: .5), 360);
    expect(smoothCompassHeading(1, 359, alpha: .5), 0);
    expect(smoothCompassHeading(720, 10, alpha: .5), 725);
    expect(smoothCompassHeading(null, 90), 90);
    expect(smoothCompassHeading(null, -90), 270);
    expect(smoothCompassHeading(90, 110, alpha: .1), 92);
  });
}

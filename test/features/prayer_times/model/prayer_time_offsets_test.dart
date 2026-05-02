import 'package:deen_lab/features/prayer_times/model/prayer_time_offsets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrayerTimeOffsets', () {
    test('defaults keep dhuhr tuned for masjid time', () {
      expect(PrayerTimeOffsets.defaults.dhuhr, 60);
      expect(PrayerTimeOffsets.defaults.tuneValue, '0,0,0,60,0,0,0,0,0');
    });

    test('copy and json round trip preserve values', () {
      final offsets = PrayerTimeOffsets.defaults.copyWith(
        fajr: 2,
        sunrise: -1,
        asr: 5,
        maghrib: 3,
        isha: -4,
      );

      final decoded = PrayerTimeOffsets.fromJson(offsets.toJson());

      expect(decoded.fajr, 2);
      expect(decoded.sunrise, -1);
      expect(decoded.dhuhr, 60);
      expect(decoded.asr, 5);
      expect(decoded.maghrib, 3);
      expect(decoded.isha, -4);
    });
  });
}

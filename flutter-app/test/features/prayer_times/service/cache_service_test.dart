import 'package:deen_lab/features/prayer_times/model/prayer_time_model.dart';
import 'package:deen_lab/features/prayer_times/model/prayer_time_offsets.dart';
import 'package:deen_lab/features/prayer_times/service/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheService', () {
    late CacheService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = CacheService();
    });

    test('persists settings including offsets', () async {
      const offsets = PrayerTimeOffsets(dhuhr: 65, asr: 4);

      await service.saveSettings(
        city: 'Peshawar',
        country: 'Pakistan',
        method: 1,
        offsets: offsets,
      );

      final settings = await service.loadSettings();

      expect(settings.city, 'Peshawar');
      expect(settings.country, 'Pakistan');
      expect(settings.method, 1);
      expect(settings.offsets.dhuhr, 65);
      expect(settings.offsets.asr, 4);
    });

    test('cached prayer data is scoped by offsets', () async {
      final prayer = PrayerTimeModel(
        fajr: '04:00',
        dhuhr: '13:05',
        asr: '16:30',
        maghrib: '18:45',
        isha: '20:00',
        sunrise: '05:25',
      );
      const savedOffsets = PrayerTimeOffsets(dhuhr: 60);

      await service.savePrayer(
        prayer,
        city: 'Peshawar',
        country: 'Pakistan',
        method: 1,
        offsets: savedOffsets,
      );

      final matching = await service.loadPrayer(
        city: 'Peshawar',
        country: 'Pakistan',
        method: 1,
        offsets: savedOffsets,
      );
      final nonMatching = await service.loadPrayer(
        city: 'Peshawar',
        country: 'Pakistan',
        method: 1,
        offsets: const PrayerTimeOffsets(dhuhr: 30),
      );

      expect(matching?.dhuhr, '13:05');
      expect(nonMatching, isNull);
    });
  });
}

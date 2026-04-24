class PrayerTimeModel {
  final String fajr;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String sunrise;

  PrayerTimeModel({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.sunrise,
  });

  factory PrayerTimeModel.fromJson(Map<String, dynamic> json) {
    final timings = json['data']['timings'];

    return PrayerTimeModel(
      fajr: timings['Fajr'],
      dhuhr: timings['Dhuhr'],
      asr: timings['Asr'],
      maghrib: timings['Maghrib'],
      isha: timings['Isha'],
      sunrise: timings['Sunrise'],
    );
  }
}

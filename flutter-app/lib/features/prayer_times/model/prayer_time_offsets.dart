class PrayerTimeOffsets {
  const PrayerTimeOffsets({
    this.fajr = 0,
    this.sunrise = 0,
    this.dhuhr = 60,
    this.asr = 0,
    this.maghrib = 0,
    this.isha = 0,
  });

  final int fajr;
  final int sunrise;
  final int dhuhr;
  final int asr;
  final int maghrib;
  final int isha;

  static const PrayerTimeOffsets defaults = PrayerTimeOffsets();

  PrayerTimeOffsets copyWith({
    int? fajr,
    int? sunrise,
    int? dhuhr,
    int? asr,
    int? maghrib,
    int? isha,
  }) {
    return PrayerTimeOffsets(
      fajr: fajr ?? this.fajr,
      sunrise: sunrise ?? this.sunrise,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
    );
  }

  Map<String, int> toJson() {
    return {
      'fajr': fajr,
      'sunrise': sunrise,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
    };
  }

  factory PrayerTimeOffsets.fromJson(Map<String, dynamic> json) {
    return PrayerTimeOffsets(
      fajr: _asInt(json['fajr']),
      sunrise: _asInt(json['sunrise']),
      dhuhr: _asInt(json['dhuhr'], fallback: defaults.dhuhr),
      asr: _asInt(json['asr']),
      maghrib: _asInt(json['maghrib']),
      isha: _asInt(json['isha']),
    );
  }

  String get tuneValue =>
      [0, fajr, sunrise, dhuhr, asr, maghrib, 0, isha, 0].join(',');

  String summaryFor(String prayerKey) {
    final minutes = switch (prayerKey) {
      'fajr' => fajr,
      'sunrise' => sunrise,
      'dhuhr' => dhuhr,
      'asr' => asr,
      'maghrib' => maghrib,
      'isha' => isha,
      _ => 0,
    };
    return formatMinutes(minutes);
  }

  static String formatMinutes(int minutes) {
    if (minutes == 0) {
      return '0 min';
    }
    if (minutes > 0) {
      return '+$minutes min';
    }
    return '$minutes min';
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    return fallback;
  }
}

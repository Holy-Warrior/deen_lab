class SehriIftariDay {
  const SehriIftariDay({
    required this.gregorianDate,
    required this.gregorianDay,
    required this.hijriDate,
    required this.hijriMonth,
    required this.imsak,
    required this.fajr,
    required this.maghrib,
    required this.timezone,
    required this.methodName,
  });

  final DateTime gregorianDate;
  final String gregorianDay;
  final String hijriDate;
  final String hijriMonth;
  final String imsak;
  final String fajr;
  final String maghrib;
  final String timezone;
  final String methodName;

  factory SehriIftariDay.fromJson(Map<String, dynamic> json) {
    final timings = json['timings'] as Map<String, dynamic>;
    final date = json['date'] as Map<String, dynamic>;
    final gregorian = date['gregorian'] as Map<String, dynamic>;
    final hijri = date['hijri'] as Map<String, dynamic>;
    final meta = json['meta'] as Map<String, dynamic>;
    final method = meta['method'] as Map<String, dynamic>;

    return SehriIftariDay(
      gregorianDate: _parseGregorianDate(gregorian['date']?.toString() ?? ''),
      gregorianDay: gregorian['weekday']?['en']?.toString() ?? '',
      hijriDate: hijri['date']?.toString() ?? '',
      hijriMonth: hijri['month']?['en']?.toString() ?? '',
      imsak: _normalizeTime(timings['Imsak']?.toString() ?? ''),
      fajr: _normalizeTime(timings['Fajr']?.toString() ?? ''),
      maghrib: _normalizeTime(timings['Maghrib']?.toString() ?? ''),
      timezone: meta['timezone']?.toString() ?? '',
      methodName: method['name']?.toString() ?? '',
    );
  }

  static DateTime _parseGregorianDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      return DateTime.now();
    }

    return DateTime(
      int.tryParse(parts[2]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[0]) ?? DateTime.now().day,
    );
  }

  static String _normalizeTime(String value) {
    return value.split(' ').first.trim();
  }
}

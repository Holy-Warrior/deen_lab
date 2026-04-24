enum PrayerMethod {
  mwl, // 3
  karachi, // 1
  ummAlQura, // 4
}

extension PrayerMethodExt on PrayerMethod {
  int get apiValue {
    switch (this) {
      case PrayerMethod.mwl:
        return 3;
      case PrayerMethod.karachi:
        return 1;
      case PrayerMethod.ummAlQura:
        return 4;
    }
  }

  String get label {
    switch (this) {
      case PrayerMethod.mwl:
        return "MWL";
      case PrayerMethod.karachi:
        return "Karachi";
      case PrayerMethod.ummAlQura:
        return "Umm Al-Qura";
    }
  }
}

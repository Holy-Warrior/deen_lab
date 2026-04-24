enum QuranReadingMode { mushaf, study }

class QuranReaderSettings {
  QuranReadingMode mode;
  double fontSize;

  QuranReaderSettings({this.mode = QuranReadingMode.mushaf, this.fontSize = 24});

  bool get showTranslation => mode == QuranReadingMode.study;

  void toggleMode() {
    mode = mode == QuranReadingMode.mushaf ? QuranReadingMode.study : QuranReadingMode.mushaf;
  }
}

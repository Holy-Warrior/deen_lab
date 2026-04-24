class HadithBook {
  const HadithBook({
    required this.collection,
    required this.bookNumber,
    required this.englishName,
    required this.arabicName,
    required this.hadithCount,
    required this.chapterCount,
  });

  final String collection;
  final String bookNumber;
  final String englishName;
  final String arabicName;
  final int hadithCount;
  final int chapterCount;

  String get title {
    if (englishName.isNotEmpty) {
      return englishName;
    }

    if (arabicName.isNotEmpty) {
      return arabicName;
    }

    return 'Book $bookNumber';
  }
}

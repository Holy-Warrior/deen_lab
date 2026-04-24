class Hadith {
  const Hadith({
    required this.id,
    required this.collection,
    required this.hadithId,
    required this.hadithNumberInBook,
    required this.bookNumber,
    required this.bookNameEnglish,
    required this.bookNameArabic,
    required this.chapterNumber,
    required this.chapterNameEnglish,
    required this.chapterNameArabic,
    required this.narratorEnglish,
    required this.englishText,
    required this.englishFull,
    required this.arabicSanad,
    required this.arabicMatn,
    required this.arabicFull,
    required this.reference,
    required this.inBookReference,
    required this.translationReference,
    required this.url,
  });

  final int id;
  final String collection;
  final String hadithId;
  final String hadithNumberInBook;
  final String bookNumber;
  final String bookNameEnglish;
  final String bookNameArabic;
  final String chapterNumber;
  final String chapterNameEnglish;
  final String chapterNameArabic;
  final String narratorEnglish;
  final String englishText;
  final String englishFull;
  final String arabicSanad;
  final String arabicMatn;
  final String arabicFull;
  final String reference;
  final String inBookReference;
  final String translationReference;
  final String url;

  String get displayNumber {
    if (hadithId.isNotEmpty) {
      return hadithId;
    }

    if (hadithNumberInBook.isNotEmpty) {
      return hadithNumberInBook;
    }

    return id.toString();
  }

  String get primaryArabicText {
    if (arabicFull.isNotEmpty) {
      return arabicFull;
    }

    if (arabicMatn.isNotEmpty) {
      return arabicMatn;
    }

    return arabicSanad;
  }

  String get primaryEnglishText {
    if (englishFull.isNotEmpty) {
      return englishFull;
    }

    return englishText;
  }
}

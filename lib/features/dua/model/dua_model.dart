class Dua {
  final String title;
  final String arabic;
  final String transliteration;
  final String translation;
  final String source;
  final String notes;

  Dua({
    required this.title,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.source,
    required this.notes,
  });

  factory Dua.fromJson(Map<String, dynamic> json) {
    return Dua(
      title: json['title'] as String? ?? '',
      arabic: json['arabic'] as String? ?? '',
      transliteration: json['transliteration'] as String? ?? json['latin'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      source: json['source'] as String? ?? '',
      notes: [
        json['notes'] as String?,
        json['fawaid'] as String?
      ].where((e) => e != null && e.isNotEmpty).join('\n\n'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'arabic': arabic,
      'transliteration': transliteration,
      'translation': translation,
      'source': source,
      'notes': notes,
    };
  }
}

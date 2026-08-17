class Dua {
  final int? id;
  final String title;
  final String? categorySlug;
  final String? categoryName;
  final String arabic;
  final String transliteration;
  final String translation;
  final String source;
  final String notes;

  Dua({
    this.id,
    required this.title,
    this.categorySlug,
    this.categoryName,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.source,
    required this.notes,
  });

  factory Dua.fromJson(Map<String, dynamic> json) {
    return Dua(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      categorySlug: json['category'] as String?,
      categoryName: json['categoryName'] as String?,
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
      'id': id,
      'title': title,
      'category': categorySlug,
      'categoryName': categoryName,
      'arabic': arabic,
      'transliteration': transliteration,
      'translation': translation,
      'source': source,
      'notes': notes,
    };
  }
}

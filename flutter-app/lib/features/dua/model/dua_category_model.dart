class DuaCategory {
  final String slug;
  final String name;

  DuaCategory({
    required this.slug,
    required this.name,
  });

  factory DuaCategory.fromJson(Map<String, dynamic> json) {
    // The Fitrahive API returns categories directly as strings, 
    // but the actual structure may vary. Assuming it returns strings for the list of categories.
    // If it returns objects, it would typically look like {"slug": "...", "name": "..."}.
    // Based on the URL structure (slugs like morning-and-evening), we will treat 
    // the string itself as the slug and generate a display name from it.
    final slugStr = json['slug'] as String? ?? '';
    final nameStr = json['name'] as String? ?? _capitalizeSlug(slugStr);
    
    return DuaCategory(
      slug: slugStr,
      name: nameStr,
    );
  }

  factory DuaCategory.fromString(String slug) {
    return DuaCategory(
      slug: slug,
      name: _capitalizeSlug(slug),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'name': name,
    };
  }

  static String _capitalizeSlug(String slug) {
    if (slug.isEmpty) return '';
    return slug.split('-').map((word) {
      if (word.isEmpty) return '';
      return "\${word[0].toUpperCase()}\${word.substring(1).toLowerCase()}";
    }).join(' ');
  }
}

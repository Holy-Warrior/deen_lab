import 'dart:convert';

class GeneratedFeature {
  const GeneratedFeature({
    required this.id,
    required this.title,
    required this.prompt,
    required this.htmlFilePath,
    required this.createdAt,
    required this.aiMessage,
  });

  final String id;
  final String title;
  final String prompt;
  final String htmlFilePath;
  final DateTime createdAt;
  final String aiMessage;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'prompt': prompt,
      'htmlFilePath': htmlFilePath,
      'createdAt': createdAt.toIso8601String(),
      'aiMessage': aiMessage,
    };
  }

  factory GeneratedFeature.fromJson(Map<String, dynamic> json) {
    return GeneratedFeature(
      id: json['id'] as String,
      title: json['title'] as String,
      prompt: json['prompt'] as String,
      htmlFilePath: json['htmlFilePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      aiMessage: json['aiMessage'] as String,
    );
  }

  static String encodeList(List<GeneratedFeature> items) {
    return jsonEncode(
      items.map((item) => item.toJson()).toList(growable: false),
    );
  }

  static List<GeneratedFeature> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => GeneratedFeature.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}

import 'dart:convert';

enum FeatureHistoryStatus { generated, declined, error }

class FeatureHistoryEntry {
  const FeatureHistoryEntry({
    required this.id,
    required this.prompt,
    required this.response,
    required this.status,
    required this.createdAt,
    this.generatedFeatureId,
    this.generatedFeatureTitle,
  });

  final String id;
  final String prompt;
  final String response;
  final FeatureHistoryStatus status;
  final DateTime createdAt;
  final String? generatedFeatureId;
  final String? generatedFeatureTitle;

  bool get hasGeneratedFeature =>
      generatedFeatureId != null && generatedFeatureId!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'response': response,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'generatedFeatureId': generatedFeatureId,
      'generatedFeatureTitle': generatedFeatureTitle,
    };
  }

  factory FeatureHistoryEntry.fromJson(Map<String, dynamic> json) {
    return FeatureHistoryEntry(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      response: json['response'] as String,
      status: FeatureHistoryStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      generatedFeatureId: json['generatedFeatureId'] as String?,
      generatedFeatureTitle: json['generatedFeatureTitle'] as String?,
    );
  }

  static String encodeList(List<FeatureHistoryEntry> items) {
    return jsonEncode(
      items.map((item) => item.toJson()).toList(growable: false),
    );
  }

  static List<FeatureHistoryEntry> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => FeatureHistoryEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }
}

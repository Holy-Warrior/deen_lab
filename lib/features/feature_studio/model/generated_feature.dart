import 'dart:convert';

class GeneratedFeatureVersion {
  const GeneratedFeatureVersion({
    required this.id,
    required this.prompt,
    required this.aiMessage,
    required this.htmlFilePath,
    required this.createdAt,
    required this.versionNumber,
  });

  final String id;
  final String prompt;
  final String aiMessage;
  final String htmlFilePath;
  final DateTime createdAt;
  final int versionNumber;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'aiMessage': aiMessage,
      'htmlFilePath': htmlFilePath,
      'createdAt': createdAt.toIso8601String(),
      'versionNumber': versionNumber,
    };
  }

  factory GeneratedFeatureVersion.fromJson(Map<String, dynamic> json) {
    return GeneratedFeatureVersion(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      aiMessage: json['aiMessage'] as String,
      htmlFilePath: json['htmlFilePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 1,
    );
  }
}

class GeneratedFeature {
  const GeneratedFeature({
    required this.id,
    required this.title,
    required this.prompt,
    required this.htmlFilePath,
    required this.createdAt,
    required this.aiMessage,
    this.activeVersionId,
    this.pendingVersionId,
    this.versions = const [],
  });

  final String id;
  final String title;
  final String prompt;
  final String htmlFilePath;
  final DateTime createdAt;
  final String aiMessage;
  final String? activeVersionId;
  final String? pendingVersionId;
  final List<GeneratedFeatureVersion> versions;

  List<GeneratedFeatureVersion> get effectiveVersions {
    if (versions.isNotEmpty) {
      return versions;
    }

    return [
      GeneratedFeatureVersion(
        id: '${id}_v1',
        prompt: prompt,
        aiMessage: aiMessage,
        htmlFilePath: htmlFilePath,
        createdAt: createdAt,
        versionNumber: 1,
      ),
    ];
  }

  GeneratedFeatureVersion get activeVersion {
    final resolvedActiveId = activeVersionId ?? effectiveVersions.first.id;
    return effectiveVersions.firstWhere(
      (version) => version.id == resolvedActiveId,
      orElse: () => effectiveVersions.first,
    );
  }

  GeneratedFeatureVersion? get pendingVersion {
    final pendingId = pendingVersionId;
    if (pendingId == null || pendingId.isEmpty) {
      return null;
    }

    for (final version in effectiveVersions) {
      if (version.id == pendingId) {
        return version;
      }
    }

    return null;
  }

  GeneratedFeatureVersion get latestVersion => effectiveVersions.reduce(
    (current, next) =>
        current.versionNumber >= next.versionNumber ? current : next,
  );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'prompt': prompt,
      'htmlFilePath': htmlFilePath,
      'createdAt': createdAt.toIso8601String(),
      'aiMessage': aiMessage,
      'activeVersionId': activeVersionId,
      'pendingVersionId': pendingVersionId,
      'versions': effectiveVersions
          .map((version) => version.toJson())
          .toList(growable: false),
    };
  }

  factory GeneratedFeature.fromJson(Map<String, dynamic> json) {
    final versionsJson = json['versions'] as List<dynamic>?;
    final versions = versionsJson == null
        ? const <GeneratedFeatureVersion>[]
        : versionsJson
              .map(
                (item) => GeneratedFeatureVersion.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false);

    return GeneratedFeature(
      id: json['id'] as String,
      title: json['title'] as String,
      prompt: json['prompt'] as String,
      htmlFilePath: json['htmlFilePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      aiMessage: json['aiMessage'] as String,
      activeVersionId: json['activeVersionId'] as String?,
      pendingVersionId: json['pendingVersionId'] as String?,
      versions: versions,
    );
  }

  GeneratedFeature copyWith({
    String? title,
    String? prompt,
    String? htmlFilePath,
    DateTime? createdAt,
    String? aiMessage,
    String? activeVersionId,
    bool clearPendingVersion = false,
    String? pendingVersionId,
    List<GeneratedFeatureVersion>? versions,
  }) {
    return GeneratedFeature(
      id: id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      htmlFilePath: htmlFilePath ?? this.htmlFilePath,
      createdAt: createdAt ?? this.createdAt,
      aiMessage: aiMessage ?? this.aiMessage,
      activeVersionId: activeVersionId ?? this.activeVersionId,
      pendingVersionId: clearPendingVersion
          ? null
          : (pendingVersionId ?? this.pendingVersionId),
      versions: versions ?? this.versions,
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

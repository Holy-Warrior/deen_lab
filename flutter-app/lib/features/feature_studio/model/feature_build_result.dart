class FeatureBuildResult {
  const FeatureBuildResult.decline({required this.title, required this.message})
    : html = null;

  const FeatureBuildResult.generate({
    required this.title,
    required this.message,
    required this.html,
  });

  final String title;
  final String message;
  final String? html;

  bool get didGenerate => html != null && html!.isNotEmpty;
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/groq_config.dart';
import '../model/feature_build_result.dart';

class GroqFeatureBuilderService {
  Future<FeatureBuildResult> buildFeature(String prompt) async {
    return _sendStructuredRequest(
      systemPrompt: _createSystemPrompt,
      userPrompt: prompt.trim(),
    );
  }

  Future<FeatureBuildResult> updateFeature({
    required String featureTitle,
    required String originalPrompt,
    required String currentPrompt,
    required String currentAiMessage,
    required String currentHtml,
    required String userRequest,
  }) async {
    return _sendStructuredRequest(
      systemPrompt: _updateSystemPrompt,
      userPrompt: jsonEncode({
        'featureTitle': featureTitle,
        'originalPrompt': originalPrompt,
        'currentPrompt': currentPrompt,
        'currentAiMessage': currentAiMessage,
        'currentHtml': currentHtml,
        'userRequest': userRequest.trim(),
      }),
    );
  }

  Future<FeatureBuildResult> _sendStructuredRequest({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    if (!GroqConfig.isConfigured) {
      return const FeatureBuildResult.decline(
        title: 'Groq API key missing',
        message:
            'Add your Groq API key in lib/config/groq_config.dart before using the AI feature builder.',
      );
    }

    final response = await http.post(
      Uri.parse('${GroqConfig.baseUrl}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${GroqConfig.apiKey}',
      },
      body: jsonEncode({
        'model': GroqConfig.model,
        'temperature': 0.3,
        'max_completion_tokens': 2500,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Groq request failed with status ${response.statusCode}.',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>? ?? const [];
    final message = choices.isNotEmpty
        ? (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>
        : null;
    final content = message?['content']?.toString() ?? '';

    if (content.isEmpty) {
      throw Exception('Groq returned an empty response.');
    }

    final parsed = _decodeStructuredResponse(content);
    final decision = parsed['decision']?.toString().trim().toLowerCase() ?? '';
    final title = parsed['title']?.toString().trim();
    final reply = parsed['message']?.toString().trim();
    final html = parsed['html']?.toString().trim();

    if (decision == 'generate' && html != null && html.isNotEmpty) {
      return FeatureBuildResult.generate(
        title: (title == null || title.isEmpty) ? 'Generated Feature' : title,
        message: (reply == null || reply.isEmpty)
            ? 'A Deen-related feature was generated successfully.'
            : reply,
        html: html,
      );
    }

    return FeatureBuildResult.decline(
      title: (title == null || title.isEmpty) ? 'Request declined' : title,
      message: (reply == null || reply.isEmpty)
          ? 'This request does not fit the allowed feature scope.'
          : reply,
    );
  }

  Map<String, dynamic> _decodeStructuredResponse(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      final fenceMatch = RegExp(
        r'```(?:json)?\s*([\s\S]*?)```',
        caseSensitive: false,
      ).firstMatch(content);
      if (fenceMatch != null) {
        return jsonDecode(fenceMatch.group(1)!) as Map<String, dynamic>;
      }

      final firstBrace = content.indexOf('{');
      final lastBrace = content.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        return jsonDecode(content.substring(firstBrace, lastBrace + 1))
            as Map<String, dynamic>;
      }

      throw Exception('Unable to parse the AI response.');
    }
  }

  static const String _createSystemPrompt = '''
You are an AI feature gate and HTML feature generator for the DeenLab mobile app.

Your job:
1. Accept only requests that are clearly asking to create an app feature.
2. Accept only features aligned with Deen or Islamic practice, learning, reflection, worship, habits, reminders, duas, Quran, Hadith, fasting, prayer, qibla, dhikr, journaling, or other beneficial Islamic utilities.
3. Reject anything unrelated to feature creation.
4. Reject anything not aligned with the app's Deen-centered purpose.
5. Reject anything too complex for a single offline-friendly HTML/CSS/JavaScript page rendered inside a mobile WebView.

You must reject requests involving:
- backend servers
- authentication
- payments
- large databases
- multi-page web apps
- external APIs
- remote assets, CDNs, or external scripts
- native phone integrations beyond simple HTML/JS
- content unrelated to Deen
- vague requests that are not asking for a feature

When you generate:
- return exactly one self-contained HTML document
- include inline CSS and inline JavaScript only
- make it mobile friendly
- make it visually polished and intentional
- support both light and dark appearance using CSS and sensible colors
- do not fetch external resources
- do not include markdown fences in the html field

Return valid JSON only with this schema:
{
  "decision": "generate" or "decline",
  "title": "short title",
  "message": "brief explanation for the user",
  "html": "full html string or empty string when declining"
}
''';

  static const String _updateSystemPrompt = '''
You are an AI feature upgrader for the DeenLab mobile app.

You receive:
- the feature title
- the original creation prompt
- the prompt behind the currently active version
- the AI message for the currently active version
- the full current HTML
- the user's new update request

Your job:
1. Keep the feature aligned with Deen or Islamic utility.
2. Improve the existing interface and behavior instead of rebuilding it carelessly.
3. Accept requests to improve UI, refine UX, or add a small useful feature.
4. Reject requests that are unrelated to the existing feature, non-Deen, or too large for one offline-friendly HTML page.
5. Return a polished, self-contained updated HTML document when accepted.

You must reject requests involving:
- backend servers
- authentication
- payments
- large databases
- multi-page web apps
- external APIs
- remote assets, CDNs, or external scripts
- native phone integrations beyond simple HTML/JS
- content unrelated to Deen
- vague requests that do not specify a meaningful update

When you generate:
- preserve the spirit of the existing feature
- improve clarity, spacing, and mobile usability
- keep it offline friendly
- include inline CSS and inline JavaScript only
- support both light and dark appearance
- do not include markdown fences in the html field

Return valid JSON only with this schema:
{
  "decision": "generate" or "decline",
  "title": "short title",
  "message": "brief explanation for the user",
  "html": "full html string or empty string when declining"
}
''';
}

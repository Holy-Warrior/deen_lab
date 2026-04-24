import 'package:flutter/material.dart';

import '../model/hadith_model.dart';

class HadithReaderScreen extends StatefulWidget {
  const HadithReaderScreen({
    super.key,
    required this.hadiths,
    required this.initialIndex,
  });

  final List<Hadith> hadiths;
  final int initialIndex;

  @override
  State<HadithReaderScreen> createState() => _HadithReaderScreenState();
}

class _HadithReaderScreenState extends State<HadithReaderScreen> {
  late final PageController _controller;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hadith ${currentIndex + 1}/${widget.hadiths.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.hadiths.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          final hadith = widget.hadiths[index];
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hadith.reference.isNotEmpty
                          ? hadith.reference
                          : 'Hadith ${hadith.displayNumber}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        hadith.collection,
                        if (hadith.bookNameEnglish.isNotEmpty)
                          hadith.bookNameEnglish,
                        if (hadith.chapterNameEnglish.isNotEmpty)
                          hadith.chapterNameEnglish,
                      ].where((part) => part.isNotEmpty).join(' • '),
                    ),
                    if (hadith.inBookReference.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(hadith.inBookReference),
                    ],
                  ],
                ),
              ),
              if (hadith.narratorEnglish.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  hadith.narratorEnglish,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
              if (hadith.primaryArabicText.isNotEmpty) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      hadith.primaryArabicText,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    hadith.primaryEnglishText,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
              ),
              if (hadith.arabicSanad.isNotEmpty &&
                  hadith.arabicSanad != hadith.primaryArabicText) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arabic Sanad',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hadith.arabicSanad,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (hadith.translationReference.isNotEmpty ||
                  hadith.url.isNotEmpty) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reference', style: theme.textTheme.titleMedium),
                        if (hadith.translationReference.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(hadith.translationReference),
                        ],
                        if (hadith.url.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SelectableText(
                            hadith.url,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

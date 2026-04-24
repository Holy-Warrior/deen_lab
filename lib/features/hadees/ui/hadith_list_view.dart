import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/hadith_controller.dart';
import '../model/hadith_book_model.dart';
import '../model/hadith_model.dart';
import 'hadith_reader_screen.dart';

class HadithListView extends StatefulWidget {
  const HadithListView({super.key, required this.book});

  final HadithBook book;

  @override
  State<HadithListView> createState() => _HadithListViewState();
}

class _HadithListViewState extends State<HadithListView> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final controller = context.read<HadithController>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.book.title),
            if (widget.book.collection.isNotEmpty)
              Text(
                widget.book.collection,
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search inside this book',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Hadith>>(
              future: controller.loadHadithsForBook(widget.book, query: query),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final hadiths = snapshot.data!;
                if (hadiths.isEmpty) {
                  return const Center(
                    child: Text('No hadith matched this search.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: hadiths.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final hadith = hadiths[index];
                    return _HadithPreviewCard(
                      hadith: hadith,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HadithReaderScreen(
                              hadiths: hadiths,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithPreviewCard extends StatelessWidget {
  const _HadithPreviewCard({required this.hadith, required this.onTap});

  final Hadith hadith;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Hadith ${hadith.displayNumber}'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hadith.chapterNameEnglish.isNotEmpty
                          ? hadith.chapterNameEnglish
                          : hadith.reference,
                      style: theme.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (hadith.narratorEnglish.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  hadith.narratorEnglish,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                hadith.primaryEnglishText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              if (hadith.primaryArabicText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  hadith.primaryArabicText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

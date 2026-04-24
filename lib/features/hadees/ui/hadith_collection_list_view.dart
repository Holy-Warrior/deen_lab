import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/hadith_controller.dart';
import '../model/hadith_collection_model.dart';
import 'hadith_book_list_view.dart';
import 'hadith_search_view.dart';

class HadithCollectionListView extends StatefulWidget {
  const HadithCollectionListView({super.key});

  @override
  State<HadithCollectionListView> createState() =>
      _HadithCollectionListViewState();
}

class _HadithCollectionListViewState extends State<HadithCollectionListView> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<HadithController>();

    if (controller.isLoadingCollections) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.loadingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.loadingError!,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.refreshCollections,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final normalizedQuery = query.trim().toLowerCase();
    final collections = controller.collections
        .where((collection) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return collection.name.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: controller.refreshCollections,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hadith Library', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Browse collections, open each book, or search the full text directly from your local database.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter collections',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor.withValues(
                      alpha: 0.86,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: controller,
                            child: const HadithSearchView(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Search Hadith Text'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Collections', style: theme.textTheme.titleLarge),
              const Spacer(),
              Text('${collections.length}', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (collections.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('No collections matched your filter.'),
            ),
          ...collections.map(
            (collection) => _CollectionCard(collection: collection),
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final HadithCollectionSummary collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final controller = context.read<HadithController>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: controller,
                child: HadithBookListView(collection: collection),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(collection.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    label: '${collection.hadithCount} hadith',
                    color: colorScheme.primaryContainer,
                  ),
                  _MetaChip(
                    label: '${collection.bookCount} books',
                    color: colorScheme.secondaryContainer,
                  ),
                  _MetaChip(
                    label: '${collection.chapterCount} chapters',
                    color: colorScheme.tertiaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

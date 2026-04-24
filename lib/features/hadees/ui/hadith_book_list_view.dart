import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/hadith_controller.dart';
import '../model/hadith_book_model.dart';
import '../model/hadith_collection_model.dart';
import 'hadith_list_view.dart';

class HadithBookListView extends StatefulWidget {
  const HadithBookListView({super.key, required this.collection});

  final HadithCollectionSummary collection;

  @override
  State<HadithBookListView> createState() => _HadithBookListViewState();
}

class _HadithBookListViewState extends State<HadithBookListView> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final controller = context.read<HadithController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.collection.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search books in this collection',
                prefixIcon: const Icon(Icons.menu_book_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<HadithBook>>(
              future: controller.loadBooks(
                widget.collection.name,
                query: query,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final books = snapshot.data!;
                if (books.isEmpty) {
                  return const Center(
                    child: Text('No books matched this filter.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final book = books[index];

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        title: Text('Book ${book.bookNumber}: ${book.title}'),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            [
                              if (book.arabicName.isNotEmpty &&
                                  book.arabicName != book.title)
                                book.arabicName,
                              '${book.hadithCount} hadith',
                              '${book.chapterCount} chapters',
                            ].join(' • '),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: controller,
                                child: HadithListView(book: book),
                              ),
                            ),
                          );
                        },
                      ),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/hadith_controller.dart';
import '../model/hadith_model.dart';
import 'hadith_reader_screen.dart';

class HadithSearchView extends StatefulWidget {
  const HadithSearchView({super.key});

  @override
  State<HadithSearchView> createState() => _HadithSearchViewState();
}

class _HadithSearchViewState extends State<HadithSearchView> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final controller = context.read<HadithController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Search Hadith')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by word or phrase',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? const Center(
                    child: Text('Type something to search the library.'),
                  )
                : FutureBuilder<List<Hadith>>(
                    future: controller.searchHadiths(query),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final hadiths = snapshot.data!;
                      if (hadiths.isEmpty) {
                        return const Center(child: Text('No results found.'));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: hadiths.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final hadith = hadiths[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              title: Text(
                                hadith.reference.isNotEmpty
                                    ? hadith.reference
                                    : 'Hadith ${hadith.displayNumber}',
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  hadith.primaryEnglishText,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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

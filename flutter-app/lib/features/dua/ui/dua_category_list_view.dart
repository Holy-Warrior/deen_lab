import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../controller/dua_controller.dart';
import '../model/dua_category_model.dart';
import 'dua_list_view.dart';
import 'dua_reader_screen.dart';

class DuaCategoryListView extends ConsumerStatefulWidget {
  const DuaCategoryListView({super.key});

  @override
  ConsumerState<DuaCategoryListView> createState() => _DuaCategoryListViewState();
}

class _DuaCategoryListViewState extends ConsumerState<DuaCategoryListView> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(duaControllerProvider);

    if (controller.isLoadingCategories && controller.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.categoriesError != null && controller.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(controller.categoriesError ?? "Failed to load Dua categories"),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(duaControllerProvider.notifier).initialize();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (controller.categories.isEmpty) {
      return const Center(child: Text("No Dua categories found."));
    }

    final q = query.toLowerCase();

    final filtered = controller.categories.where((c) {
      return c.name.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search categories or any dua...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? RefreshIndicator(
                  onRefresh: () async {
                     await ref.read(duaControllerProvider.notifier).initialize();
                  },
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final DuaCategory category = filtered[index];

                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.volunteer_activism_rounded, color: Colors.white),
                        ),
                        title: _highlight(category.name, query),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DuaListView(category: category),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              : _buildGlobalSearchResults(controller),
        ),
      ],
    );
  }

  Widget _buildGlobalSearchResults(DuaController controller) {
    final results = controller.searchAllCachedDuas(query);
    
    if (results.isEmpty) {
      return Center(child: Text('No duas found for "\$query"'));
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final dua = results[index];
        final categoryName = dua.categoryName ?? 'Unknown Category';
        final categorySlug = dua.categorySlug ?? '';
        
        return ListTile(
          leading: const Icon(Icons.book, color: Colors.green),
          title: _highlight(dua.title, query),
          subtitle: Text(categoryName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DuaReaderScreen(
                  dua: dua,
                  categoryName: categoryName,
                  categorySlug: categorySlug,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _highlight(String text, String query) {
    if (query.isEmpty) return Text(text);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    final start = lowerText.indexOf(lowerQuery);

    if (start == -1) return Text(text);

    final end = start + query.length;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
        style: DefaultTextStyle.of(context).style,
      ),
    );
  }
}

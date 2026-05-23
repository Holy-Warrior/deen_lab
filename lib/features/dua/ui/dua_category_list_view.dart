import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../model/dua_category_model.dart';
import 'dua_list_view.dart';

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
              hintText: "Search categories",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
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
          ),
        ),
      ],
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

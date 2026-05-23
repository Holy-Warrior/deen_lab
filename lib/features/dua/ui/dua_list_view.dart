import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../model/dua_category_model.dart';
import '../model/dua_model.dart';
import 'dua_reader_screen.dart';

class DuaListView extends ConsumerStatefulWidget {
  final DuaCategory category;

  const DuaListView({
    super.key,
    required this.category,
  });

  @override
  ConsumerState<DuaListView> createState() => _DuaListViewState();
}

class _DuaListViewState extends ConsumerState<DuaListView> {
  String query = "";
  List<Dua> _duas = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDuas();
  }

  Future<void> _loadDuas() async {
    try {
      final controller = ref.read(duaControllerProvider.notifier);
      final duas = await controller.loadDuasForCategory(widget.category.slug);
      
      if (mounted) {
        setState(() {
          _duas = duas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _duas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadDuas();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_duas.isEmpty) {
      return const Center(child: Text("No duas found in this category."));
    }

    final q = query.toLowerCase();

    final filtered = _duas.where((d) {
      return d.title.toLowerCase().contains(q) ||
             d.translation.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search by title or translation",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final Dua dua = filtered[index];

              return ListTile(
                title: _highlight(dua.title.isNotEmpty ? dua.title : 'Dua \${index + 1}', query),
                subtitle: Text(
                  dua.translation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DuaReaderScreen(
                        dua: dua,
                        categoryName: widget.category.name,
                      ),
                    ),
                  );
                },
              );
            },
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

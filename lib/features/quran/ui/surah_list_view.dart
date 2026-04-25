import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/quran_controller.dart';
import '../model/surah_model.dart';
import 'surah_reader_screen.dart';

class SurahListView extends StatefulWidget {
  const SurahListView({super.key});

  @override
  State<SurahListView> createState() => _SurahListViewState();
}

class _SurahListViewState extends State<SurahListView> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuranController>();

    if (controller.isSurahListLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.surahs.isEmpty) {
      return Center(
        child: Text(controller.loadingError ?? "Failed to load Quran"),
      );
    }

    final q = query.toLowerCase();

    final filtered = controller.surahs.where((s) {
      return s.englishName.toLowerCase().contains(q) ||
          s.name.contains(q) ||
          s.number.toString().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search Surah (name or number)",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final Surah s = filtered[index];

              return ListTile(
                title: _highlight("${s.number}. ${s.englishName}", query),
                subtitle: _highlight(s.name, query),
                trailing: _highlight("${s.ayahCount}", query),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: controller,
                        child: SurahReaderScreen(surah: s),
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

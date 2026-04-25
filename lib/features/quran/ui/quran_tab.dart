import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/quran_controller.dart';
import 'surah_list_view.dart';

class QuranTab extends StatelessWidget {
  const QuranTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QuranController()..loadSurahs(),
      child: const SurahListView(),
    );
  }
}

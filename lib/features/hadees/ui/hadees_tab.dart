import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/hadith_controller.dart';
import 'hadith_collection_list_view.dart';

class HadeesTab extends StatelessWidget {
  const HadeesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HadithController()..initialize(),
      child: const HadithCollectionListView(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/sehri_iftari_controller.dart';
import 'sehri_iftari_view.dart';

class SehriIftariTab extends StatelessWidget {
  const SehriIftariTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SehriIftariController()..load(),
      child: const SehriIftariView(),
    );
  }
}

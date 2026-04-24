import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/qibla_controller.dart';
import 'qibla_view.dart';

class QiblaTab extends StatelessWidget {
  const QiblaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QiblaController()..load(),
      child: const QiblaView(),
    );
  }
}

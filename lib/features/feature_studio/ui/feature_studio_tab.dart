import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_shell/tab_model_and_controller.dart';
import '../controller/feature_studio_controller.dart';
import 'feature_studio_view.dart';

class FeatureStudioTab extends StatelessWidget {
  const FeatureStudioTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeatureStudioController(
        tabController: context.read<DeenLabTabController>(),
      )..loadHistory(),
      child: const FeatureStudioView(),
    );
  }
}

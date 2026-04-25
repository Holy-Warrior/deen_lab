import 'package:deen_lab/features/feature_studio/ui/feature_studio_tab.dart';
import 'package:deen_lab/features/feature_studio/ui/generated_feature_webview_tab.dart';
import 'package:deen_lab/features/hadees/ui/hadees_tab.dart';
import 'package:deen_lab/features/prayer_times/prayer_time_tab.dart';
import 'package:deen_lab/features/qibla/ui/qibla_tab.dart';
import 'package:deen_lab/features/quran/ui/quran_tab.dart';
import 'package:deen_lab/features/sehri_iftari/ui/sehri_iftari_tab.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:widget_git_release_checker/widget_git_release_checker.dart';

import 'tab_model_and_controller.dart';
import 'widgets/tab_text_view.dart';

class TabScreen extends StatelessWidget {
  const TabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeenLabTabController(),
      child: const _TabScreenBody(),
    );
  }
}

class _TabScreenBody extends StatefulWidget {
  const _TabScreenBody();

  @override
  State<_TabScreenBody> createState() => _TabScreenBodyState();
}

class _TabScreenBodyState extends State<_TabScreenBody>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _currentLength = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final tabCtrl = context.watch<DeenLabTabController>();
    final tabs = tabCtrl.tabs;

    if (_tabController == null || _currentLength != tabs.length) {
      final targetIndex = tabCtrl.targetIndex;

      _tabController?.dispose();

      _tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: targetIndex.clamp(0, tabs.length - 1),
      );

      _currentLength = tabs.length;
    } else if (_tabController != null &&
        _tabController!.index !=
            tabCtrl.targetIndex.clamp(0, tabs.length - 1)) {
      _tabController!.animateTo(tabCtrl.targetIndex.clamp(0, tabs.length - 1));
    }
  }

  Widget _buildTabContent(DeenLabTab tab) {
    switch (tab.type) {
      case TabType.prayer:
        return const PrayerTimeTab();
      case TabType.sehriIftari:
        return const SehriIftariTab();
      case TabType.qibla:
        return const QiblaTab();
      case TabType.quran:
        return const QuranTab();
      case TabType.hadees:
        return const HadeesTab();
      case TabType.generatedFeature:
        return GeneratedFeatureWebViewTab(feature: tab.generatedFeature!);
      case TabType.text:
        return const TabTextView();
      case TabType.addNew:
        return const FeatureStudioTab();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabCtrl = context.watch<DeenLabTabController>();
    final tabs = tabCtrl.tabs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DeenLab'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: WidgetGitReleaseChecker(
                  user: 'Holy-Warrior',
                  repo: 'deen_lab',
                  currentRelease: 'v1.0.0',
                  filterOutPreRelease: true,
                  showLoading: false,
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                onTap: (index) {
                  context.read<DeenLabTabController>().setIndex(index);
                },
                tabs: tabs.map((tab) => Tab(text: tab.title)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabs.map(_buildTabContent).toList(),
      ),
    );
  }
}

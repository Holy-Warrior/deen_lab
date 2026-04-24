import 'package:flutter/material.dart';

class DeenLabTab {
  final String id;
  final String title;
  final TabType type;

  DeenLabTab({required this.id, required this.title, required this.type});
}

enum TabType {
  list,
  text,
  button,
  box,
  addNew,
  prayer,
  sehriIftari,
  qibla,
  quran,
  hadees,
}

class DeenLabTabController extends ChangeNotifier {
  final List<DeenLabTab> _tabs = [
    DeenLabTab(id: 'home', title: 'Home', type: TabType.text),
    DeenLabTab(id: 'prayer', title: 'Prayer Times', type: TabType.prayer),
    DeenLabTab(
      id: 'sehri-iftari',
      title: 'Sehri & Iftari',
      type: TabType.sehriIftari,
    ),
    DeenLabTab(id: 'qibla', title: 'Qibla', type: TabType.qibla),
    DeenLabTab(id: 'quran', title: 'Quran', type: TabType.quran),
    DeenLabTab(id: 'hadees', title: 'Hadees', type: TabType.hadees),
    DeenLabTab(id: 'list', title: 'List', type: TabType.list),
    DeenLabTab(id: 'action', title: 'Action', type: TabType.button),
    DeenLabTab(id: 'box', title: 'Box', type: TabType.box),
    DeenLabTab(id: 'add', title: '+', type: TabType.addNew),
  ];

  int _targetIndex = 0;

  List<DeenLabTab> get tabs => List.unmodifiable(_tabs);
  int get targetIndex => _targetIndex;

  void setIndex(int index) {
    _targetIndex = index;
  }

  void addNewTab() {
    final newIndex = _tabs.length - 1;

    _tabs.insert(
      newIndex,
      DeenLabTab(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New',
        type: TabType.text,
      ),
    );

    _targetIndex = newIndex;
    notifyListeners();
  }
}

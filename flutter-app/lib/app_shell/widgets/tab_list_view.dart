import 'package:flutter/material.dart';

class TabListView extends StatelessWidget {
  const TabListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 20,
      itemBuilder: (_, i) => Card(
        child: ListTile(
          leading: const Icon(Icons.star),
          title: Text('Item $i'),
        ),
      ),
    );
  }
}

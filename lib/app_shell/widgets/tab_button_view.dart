import 'package:flutter/material.dart';

class TabButtonView extends StatelessWidget {
  const TabButtonView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(onPressed: () {}, child: const Text("Press Me")),
    );
  }
}

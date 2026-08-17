import 'package:flutter/material.dart';

class TabBoxView extends StatelessWidget {
  const TabBoxView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        height: 160,
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),

          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF1ABC9C),
                    Color(0xFF0F9D8A),
                    Color(0xFF0E7C6B),
                  ]
                : [Colors.teal.shade300, Colors.blue.shade300],
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25), // FIXED
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      ),
    );
  }
}

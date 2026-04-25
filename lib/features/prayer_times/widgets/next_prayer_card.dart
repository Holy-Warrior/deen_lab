import 'package:flutter/material.dart';

class NextPrayerCard extends StatelessWidget {
  final String nextPrayer;
  final String time;
  final String remaining;

  const NextPrayerCard({
    super.key,
    required this.nextPrayer,
    required this.time,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1ABC9C), Color(0xFF0F9D8A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Next Prayer", style: TextStyle(color: Colors.black87)),
          const SizedBox(height: 6),
          Text(
            "$nextPrayer - $time",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Remaining: $remaining",
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

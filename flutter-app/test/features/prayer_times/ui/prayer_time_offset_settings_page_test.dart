import 'package:deen_lab/features/prayer_times/model/prayer_time_offsets.dart';
import 'package:deen_lab/features/prayer_times/ui/prayer_time_offset_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offset settings page updates and resets values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrayerTimeOffsetSettingsPage(
          initialOffsets: PrayerTimeOffsets(dhuhr: 60, fajr: 1),
        ),
      ),
    );

    expect(find.text('Prayer Time Offsets'), findsOneWidget);
    expect(find.text('+60 min'), findsOneWidget);
    expect(find.text('+1 min'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase Dhuhr'));
    await tester.pumpAndSettle();
    expect(find.text('+61 min'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('+60 min'), findsOneWidget);
    expect(find.text('0 min'), findsWidgets);
  });
}

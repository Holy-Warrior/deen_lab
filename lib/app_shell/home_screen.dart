import 'package:deen_lab/features/feature_studio/ui/feature_studio_tab.dart';
import 'package:deen_lab/features/prayer_times/controller/prayer_time_controller.dart';
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeenLabTabController()),
        ChangeNotifierProvider(create: (_) => PrayerTimeController()..load()),
      ],
      child: const _HomeScreenBody(),
    );
  }
}

class _HomeScreenBody extends StatelessWidget {
  const _HomeScreenBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppHeader(),
            Expanded(child: _HomeGrid()),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SafeArea(
            top: false,
            child: _PrayerStrip(),
          ),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DeenLab',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0D2B1D),
                ),
              ),
              Text(
                'Your Islamic companion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          const _UpdateBadge(),
        ],
      ),
    );
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 160,
      child: WidgetGitReleaseChecker(
        user: 'Holy-Warrior',
        repo: 'deen_lab',
        currentRelease: 'v1.0.0',
        filterOutPreRelease: true,
        showLoading: false,
      ),
    );
  }
}

class _HomeGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tabCtrl = context.watch<DeenLabTabController>();

    if (tabCtrl.isRestoring) {
      return const Center(child: CircularProgressIndicator());
    }

    return _BentoGrid(controller: tabCtrl);
  }
}

class _BentoGrid extends StatelessWidget {
  const _BentoGrid({required this.controller});

  final DeenLabTabController controller;

  @override
  Widget build(BuildContext context) {
    final generatedFeatures = controller.generatedFeatures;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildListDelegate([
              _FeatureCard(
                type: _CardType.prayer,
                icon: Icons.access_time_filled_rounded,
                label: 'Prayer Times',
                accent: const Color(0xFF4CAF7D),
                onTap: () => _openPage(context, const PrayerTimeTab(), 'Prayer Times'),
              ),
              _FeatureCard(
                type: _CardType.quran,
                icon: Icons.menu_book_rounded,
                label: 'Quran',
                accent: const Color(0xFF7C6AF7),
                onTap: () => _openPage(context, const QuranTab(), 'Quran'),
              ),
              _FeatureCard(
                type: _CardType.qibla,
                icon: Icons.explore_rounded,
                label: 'Qibla',
                accent: const Color(0xFFE8A95B),
                onTap: () => _openPage(context, const QiblaTab(), 'Qibla'),
              ),
              _FeatureCard(
                type: _CardType.sehri,
                icon: Icons.nights_stay_rounded,
                label: 'Sehri & Iftari',
                accent: const Color(0xFF5BB3E8),
                onTap: () => _openPage(context, const SehriIftariTab(), 'Sehri & Iftari'),
              ),
              _FeatureCard(
                type: _CardType.hadees,
                icon: Icons.auto_stories_rounded,
                label: 'Hadees',
                accent: const Color(0xFFE85B8A),
                onTap: () => _openPage(context, const HadeesTab(), 'Hadees'),
              ),
              ...generatedFeatures.map(
                (feature) => _FeatureCard(
                  type: _CardType.generated,
                  icon: Icons.bolt_rounded,
                  label: feature.title,
                  accent: const Color(0xFF9C6AF7),
                  onTap: () => _openPage(
                    context,
                    GeneratedFeatureWebViewTab(feature: feature),
                    feature.title,
                  ),
                ),
              ),
              _AddNewCard(
                onTap: () => _openPage(context, const FeatureStudioTab(), 'Feature Studio'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _openPage(BuildContext context, Widget page, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FeaturePage(title: title, child: page),
      ),
    );
  }
}

enum _CardType { prayer, quran, qibla, sehri, hadees, generated }

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.type,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final _CardType type;
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? Color.lerp(const Color(0xFF161B22), widget.accent, 0.08)!
        : Colors.white;
    final iconBg = widget.accent.withValues(alpha: isDark ? 0.22 : 0.13);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? widget.accent.withValues(alpha: 0.18)
                  : const Color(0xFFE8EDE9),
              width: 1.2,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 26),
              ),
              const Spacer(),
              Text(
                widget.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0D2B1D),
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Open',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddNewCard extends StatefulWidget {
  const _AddNewCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddNewCard> createState() => _AddNewCardState();
}

class _AddNewCardState extends State<_AddNewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: DottedBorderCard(
          isDark: isDark,
          colorScheme: colorScheme,
          theme: theme,
        ),
      ),
    );
  }
}

class DottedBorderCard extends StatelessWidget {
  const DottedBorderCard({
    super.key,
    required this.isDark,
    required this.colorScheme,
    required this.theme,
  });

  final bool isDark;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: isDark
            ? colorScheme.primary.withValues(alpha: 0.35)
            : const Color(0xFFB2CCBA),
        borderRadius: 24,
        dashWidth: 6,
        dashSpace: 5,
        strokeWidth: 1.5,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.primary.withValues(alpha: 0.06)
              : const Color(0xFFF4F9F5),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.add_rounded,
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            const Spacer(),
            Text(
              'Feature Studio',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF3D6B4E),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI-powered',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            distance + dashWidth,
          ),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace;
}

/// Wraps each feature in a Scaffold with a back button
class _FeaturePage extends StatelessWidget {
  const _FeaturePage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        elevation: 0,
      ),
      body: child,
    );
  }
}

/// A slim bottom strip that shows the next prayer and a live countdown.
/// It reads from the [PrayerTimeController] already provided at the [HomeScreen] level.
class _PrayerStrip extends StatelessWidget {
  const _PrayerStrip();

  static const _prayerIcons = {
    'Fajr': Icons.wb_twilight_rounded,
    'Dhuhr': Icons.wb_sunny_rounded,
    'Asr': Icons.light_mode_rounded,
    'Maghrib': Icons.wb_twilight_rounded,
    'Isha': Icons.nightlight_round,
  };

  void _openPrayerPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _FeaturePage(
          title: 'Prayer Times',
          child: PrayerTimeTab(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PrayerTimeController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Loading state — show a slim shimmer placeholder
    if (ctrl.isLoading) {
      return _StripShell(
        isDark: isDark,
        colorScheme: colorScheme,
        onTap: null,
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Loading prayer times…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Error / no data state
    if (ctrl.data == null) {
      return _StripShell(
        isDark: isDark,
        colorScheme: colorScheme,
        onTap: () => _openPrayerPage(context),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
            const SizedBox(width: 10),
            Text(
              'Prayer times unavailable — tap to retry',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final icon = _prayerIcons[ctrl.nextPrayerName] ?? Icons.access_time_rounded;
    final accentGreen = isDark ? const Color(0xFF4CAF7D) : const Color(0xFF2E7D5E);

    return _StripShell(
      isDark: isDark,
      colorScheme: colorScheme,
      onTap: () => _openPrayerPage(context),
      child: Row(
        children: [
          // Prayer icon bubble
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentGreen.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accentGreen),
          ),
          const SizedBox(width: 12),
          // Next prayer name + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ctrl.nextPrayerName,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0D2B1D),
                ),
              ),
              Text(
                ctrl.nextPrayerTime,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Live countdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ctrl.remainingTime,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: accentGreen,
                ),
              ),
              Text(
                'remaining',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StripShell extends StatelessWidget {
  const _StripShell({
    required this.isDark,
    required this.colorScheme,
    required this.onTap,
    required this.child,
  });

  final bool isDark;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF161B22)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? const Color(0xFF4CAF7D).withValues(alpha: 0.18)
                : const Color(0xFFD6EBE0),
            width: 1.2,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF4CAF7D).withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

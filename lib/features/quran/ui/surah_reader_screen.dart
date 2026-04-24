import 'package:deen_lab/features/quran/model/quran_reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/quran_controller.dart';
import '../model/surah_model.dart';
import '../model/ayah_model.dart';

class SurahReaderScreen extends StatefulWidget {
  final Surah surah;

  const SurahReaderScreen({super.key, required this.surah});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  late Future<List<Ayah>> _future;
  final ScrollController _scrollController = ScrollController();

  double progress = 0;
  bool isDragging = false;

  List<Ayah> ayahs = [];

  @override
  void initState() {
    super.initState();

    final controller = context.read<QuranController>();
    _future = controller.loadSurah(widget.surah.number);

    _scrollController.addListener(() {
      if (!_scrollController.hasClients || isDragging) return;

      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;

      if (max > 0) {
        setState(() {
          progress = (current / max).clamp(0, 1);
        });
      }
    });
  }

  void _openSettings(QuranController controller) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return ChangeNotifierProvider.value(value: controller, child: const _ReaderSettingsSheet());
      },
    );
  }

  int get currentAyahIndex {
    if (ayahs.isEmpty) return 0;
    return (progress * ayahs.length).clamp(0, ayahs.length - 1).toInt();
  }

  void _onScrub(double value) {
    if (!_scrollController.hasClients) return;

    final max = _scrollController.position.maxScrollExtent;
    final target = value * max;

    _scrollController.jumpTo(target);

    setState(() {
      progress = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuranController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surah.englishName),
        actions: [IconButton(icon: const Icon(Icons.tune), onPressed: () => _openSettings(controller))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor, // 👈 separation
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildScrubber(),
          ),
        ),
      ),
      body: FutureBuilder<List<Ayah>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          ayahs = snapshot.data!;
          final settings = controller.readerSettings;

          return Stack(
            children: [
              settings.mode == QuranReadingMode.mushaf ? _buildMushafView(settings) : _buildStudyView(settings),

              if (isDragging) _buildCenterIndicator(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMushafView(QuranReaderSettings settings) {
    final fullText = ayahs.map((a) => "${a.text} ۝").join(" ");

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Text(
        fullText,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: settings.fontSize, height: 2),
      ),
    );
  }

  Widget _buildStudyView(QuranReaderSettings settings) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: ayahs.length,
      itemBuilder: (context, index) {
        final a = ayahs[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                a.text,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: settings.fontSize),
              ),
              const SizedBox(height: 8),
              Text(a.translation),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrubber() {
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              setState(() => isDragging = true);
            },
            onHorizontalDragEnd: (_) {
              setState(() => isDragging = false);
            },
            onHorizontalDragUpdate: (details) {
              final dx = details.localPosition.dx;
              final value = (dx / width).clamp(0.0, 1.0);
              _onScrub(value);
            },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: isDragging ? 14 : 6,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(12)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterIndicator() {
    final ayahNumber = currentAyahIndex + 1;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
        child: Text(
          "Ayah $ayahNumber",
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ReaderSettingsSheet extends StatelessWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<QuranController>(
      builder: (_, c, _) {
        final s = c.readerSettings;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Reader Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(min: 18, max: 32, value: s.fontSize, onChanged: c.updateFontSize),
              ElevatedButton(
                onPressed: c.toggleMode,
                child: Text(s.mode == QuranReadingMode.mushaf ? "Study Mode" : "Mushaf Mode"),
              ),
            ],
          ),
        );
      },
    );
  }
}

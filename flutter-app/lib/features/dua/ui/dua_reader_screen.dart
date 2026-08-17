import 'package:flutter/material.dart';

import '../model/dua_model.dart';
import '../service/dua_service.dart';

class DuaReaderScreen extends StatefulWidget {
  final Dua dua;
  final String categoryName;
  final String categorySlug;

  const DuaReaderScreen({
    super.key,
    required this.dua,
    required this.categoryName,
    required this.categorySlug,
  });

  @override
  State<DuaReaderScreen> createState() => _DuaReaderScreenState();
}

class _DuaReaderScreenState extends State<DuaReaderScreen> {
  late Dua _dua;
  bool _isLoading = false;
  String? _error;
  final DuaService _duaService = DuaService();

  @override
  void initState() {
    super.initState();
    _dua = widget.dua;
    
    if (_dua.arabic.isEmpty && _dua.id != null) {
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fetchedDetail = await _duaService.fetchDuaDetail(widget.categorySlug, _dua.id!);
      if (mounted) {
        setState(() {
          _dua = fetchedDetail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load details. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        titleSpacing: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchDetail, 
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_dua.title.isNotEmpty) ...[
                    Text(
                      _dua.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Arabic Text
                  if (_dua.arabic.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        _dua.arabic,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'Amiri', // Or your app's preferred Arabic font
                          fontSize: 28,
                          height: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Transliteration
                  if (_dua.transliteration.isNotEmpty) ...[
                    const Text(
                      'Transliteration',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dua.transliteration,
                      style: const TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Translation
                  if (_dua.translation.isNotEmpty) ...[
                    const Text(
                      'Translation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dua.translation,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Source/Reference
                  if (_dua.source.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _dua.source,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Notes/Fawaid
                  if (_dua.notes.isNotEmpty) ...[
                    const Text(
                      'Notes & Benefits',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dua.notes,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
    );
  }
}

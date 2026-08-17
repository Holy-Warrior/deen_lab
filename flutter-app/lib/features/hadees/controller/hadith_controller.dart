import 'package:flutter/material.dart';

import '../model/hadith_book_model.dart';
import '../model/hadith_collection_model.dart';
import '../model/hadith_model.dart';
import '../service/hadith_service.dart';

class HadithController extends ChangeNotifier {
  final HadithService _service = HadithService();
  bool _disposed = false;

  final Map<String, List<HadithBook>> _booksCache = {};
  final Map<String, List<Hadith>> _bookHadithCache = {};
  final Map<String, List<Hadith>> _searchCache = {};

  List<HadithCollectionSummary> collections = [];
  bool isLoadingCollections = false;
  String? loadingError;

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    if (collections.isNotEmpty || isLoadingCollections) {
      return;
    }

    isLoadingCollections = true;
    loadingError = null;
    _safeNotifyListeners();

    try {
      await _service.initialize();
      if (_disposed) {
        return;
      }
      collections = await _service.fetchCollections();
      if (_disposed) {
        return;
      }
    } catch (error) {
      if (_disposed) {
        return;
      }
      loadingError = 'Unable to load hadith library.';
      collections = [];
    } finally {
      isLoadingCollections = false;
      _safeNotifyListeners();
    }
  }

  Future<void> refreshCollections() async {
    collections = [];
    _booksCache.clear();
    _bookHadithCache.clear();
    _searchCache.clear();
    await initialize();
  }

  Future<List<HadithBook>> loadBooks(
    String collection, {
    String query = '',
  }) async {
    final key = '${collection.trim()}|${query.trim().toLowerCase()}';
    final cached = _booksCache[key];
    if (cached != null) {
      return cached;
    }

    final books = await _service.fetchBooks(collection, query: query);
    _booksCache[key] = books;
    return books;
  }

  Future<List<Hadith>> loadHadithsForBook(
    HadithBook book, {
    String query = '',
  }) async {
    final key = [
      book.collection.trim(),
      book.bookNumber.trim(),
      query.trim().toLowerCase(),
    ].join('|');
    final cached = _bookHadithCache[key];
    if (cached != null) {
      return cached;
    }

    final hadiths = await _service.fetchHadithsForBook(book, query: query);
    _bookHadithCache[key] = hadiths;
    return hadiths;
  }

  Future<List<Hadith>> searchHadiths(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    final cached = _searchCache[normalized];
    if (cached != null) {
      return cached;
    }

    final hadiths = await _service.searchHadiths(query);
    _searchCache[normalized] = hadiths;
    return hadiths;
  }

  @override
  void dispose() {
    _disposed = true;
    _service.dispose();
    super.dispose();
  }
}

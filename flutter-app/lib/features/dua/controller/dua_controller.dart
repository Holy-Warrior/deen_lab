import 'package:flutter/material.dart';

import '../model/dua_category_model.dart';
import '../model/dua_model.dart';
import '../service/dua_service.dart';
import '../service/dua_cache_service.dart';

class DuaController extends ChangeNotifier {
  final DuaService _service = DuaService();
  final DuaCacheService _cacheService = DuaCacheService();

  List<DuaCategory> categories = [];
  bool isLoadingCategories = false;
  String? categoriesError;

  final Map<String, List<Dua>> _duaCache = {};
  
  bool _disposed = false;

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    if (categories.isNotEmpty || isLoadingCategories) {
      return;
    }

    isLoadingCategories = true;
    categoriesError = null;
    _safeNotifyListeners();

    try {
      // Try to load from cache first
      final cachedCategories = await _cacheService.loadCategories();
      if (_disposed) return;

      if (cachedCategories != null && cachedCategories.isNotEmpty) {
        categories = cachedCategories;
        isLoadingCategories = false;
        _safeNotifyListeners();
        
        // Fetch fresh data in the background
        _refreshCategoriesInBackground();
        _prefetchAllDuas(cachedCategories);
      } else {
        // Cache miss or expired, fetch from API
        final fetchedCategories = await _service.fetchCategories();
        if (_disposed) return;
        
        categories = fetchedCategories;
        await _cacheService.saveCategories(categories);
        _prefetchAllDuas(categories);
      }
    } catch (e) {
      if (_disposed) return;
      
      // If API fails, try to load from cache even if expired
      if (categories.isEmpty) {
         categoriesError = e.toString();
      }
    } finally {
      isLoadingCategories = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _prefetchAllDuas(List<DuaCategory> cats) async {
    for (final category in cats) {
      await loadDuasForCategory(category.slug);
    }
    _safeNotifyListeners(); // Notify when all are loaded so global search works
  }

  Future<void> _refreshCategoriesInBackground() async {
    try {
      final fetchedCategories = await _service.fetchCategories();
      if (_disposed) return;
      
      // Update cache and memory if successful
      categories = fetchedCategories;
      await _cacheService.saveCategories(categories);
      _safeNotifyListeners();
    } catch (_) {
      // Ignore background refresh errors
    }
  }

  Future<List<Dua>> loadDuasForCategory(String categorySlug) async {
    if (_duaCache.containsKey(categorySlug)) {
      final cached = _duaCache[categorySlug]!;
      // Invalidate if the cache contains old models without IDs
      if (cached.isNotEmpty && cached.first.id != null) {
        return cached;
      }
    }

    try {
      // Try to load from cache first
      final cachedDuas = await _cacheService.loadDuasForCategory(categorySlug);
      if (_disposed) return [];

      if (cachedDuas != null && cachedDuas.isNotEmpty) {
        _duaCache[categorySlug] = cachedDuas;
        
        // Fetch fresh data in the background
        _refreshDuasInBackground(categorySlug);
        
        return cachedDuas;
      }

      // Cache miss or expired, fetch from API
      final fetchedDuas = await _service.fetchDuasForCategory(categorySlug);
      if (_disposed) return [];

      _duaCache[categorySlug] = fetchedDuas;
      await _cacheService.saveDuasForCategory(categorySlug, fetchedDuas);
      return fetchedDuas;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _refreshDuasInBackground(String categorySlug) async {
    try {
      final fetchedDuas = await _service.fetchDuasForCategory(categorySlug);
      if (_disposed) return;
      
      _duaCache[categorySlug] = fetchedDuas;
      await _cacheService.saveDuasForCategory(categorySlug, fetchedDuas);
      // We don't notify listeners here to avoid jarring UI updates while reading
    } catch (_) {
      // Ignore background refresh errors
    }
  }

  List<Dua> searchAllCachedDuas(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final List<Dua> results = [];

    for (final category in categories) {
      final duas = _duaCache[category.slug] ?? [];
      for (final dua in duas) {
        if (dua.title.toLowerCase().contains(lowerQuery)) {
          // Double check it has category name for the UI
          final duaWithCategory = dua.categoryName == null 
              ? Dua(
                  id: dua.id,
                  title: dua.title,
                  categorySlug: category.slug,
                  categoryName: category.name,
                  arabic: dua.arabic,
                  transliteration: dua.transliteration,
                  translation: dua.translation,
                  source: dua.source,
                  notes: dua.notes,
                )
              : dua;
          results.add(duaWithCategory);
        }
      }
    }
    return results;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

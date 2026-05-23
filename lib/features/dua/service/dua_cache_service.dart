import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/dua_category_model.dart';
import '../model/dua_model.dart';

class DuaCacheService {
  static const String _categoriesKey = 'dua_categories_cache';
  static const String _categoriesTimestampKey = 'dua_categories_cache_timestamp';
  
  // Cache valid for 7 days
  static const Duration _cacheTtl = Duration(days: 7);

  Future<void> saveCategories(List<DuaCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = categories.map((c) => c.toJson()).toList();
    await prefs.setString(_categoriesKey, jsonEncode(jsonList));
    await prefs.setInt(_categoriesTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<DuaCategory>?> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    
    final timestamp = prefs.getInt(_categoriesTimestampKey);
    if (timestamp != null) {
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheDate) > _cacheTtl) {
        // Cache expired
        return null;
      }
    } else {
      return null;
    }

    final jsonString = prefs.getString(_categoriesKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => DuaCategory.fromJson(json)).toList();
    }
    return null;
  }

  Future<void> saveDuasForCategory(String slug, List<Dua> duas) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = duas.map((d) => d.toJson()).toList();
    await prefs.setString('dua_category_${slug}', jsonEncode(jsonList));
    await prefs.setInt('dua_category_timestamp_${slug}', DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Dua>?> loadDuasForCategory(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    
    final timestamp = prefs.getInt('dua_category_timestamp_${slug}');
    if (timestamp != null) {
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheDate) > _cacheTtl) {
        // Cache expired
        return null;
      }
    } else {
      return null;
    }

    final jsonString = prefs.getString('dua_category_${slug}');
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Dua.fromJson(json)).toList();
    }
    return null;
  }
}

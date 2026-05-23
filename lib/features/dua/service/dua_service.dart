import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/dua_category_model.dart';
import '../model/dua_model.dart';

class DuaService {
  Future<List<DuaCategory>> fetchCategories() async {
    final uri = Uri.parse('https://dua-dhikr.vercel.app/categories');
    
    final response = await http.get(uri, headers: {'Accept-Language': 'en'}).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> data = body['data'];
      
      return data.map((json) => DuaCategory.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load dua categories');
    }
  }

  Future<List<Dua>> fetchDuasForCategory(String categorySlug) async {
    final uri = Uri.parse('https://dua-dhikr.vercel.app/categories/${categorySlug}');
    
    final response = await http.get(uri, headers: {'Accept-Language': 'en'}).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> data = body['data'];
      
      return data.map((item) => Dua.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load duas for category: ${categorySlug}');
    }
  }

  Future<Dua> fetchDuaDetail(String categorySlug, int id) async {
    final uri = Uri.parse('https://dua-dhikr.vercel.app/categories/${categorySlug}/${id}');
    final response = await http.get(uri, headers: {'Accept-Language': 'en'}).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return Dua.fromJson(body['data']);
    } else {
      throw Exception('Failed to load dua detail');
    }
  }
}

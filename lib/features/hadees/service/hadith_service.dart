import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../model/hadith_book_model.dart';
import '../model/hadith_collection_model.dart';
import '../model/hadith_model.dart';

class HadithService {
  static const String _assetPath = 'resources/hadith.db';
  static const String _databaseName = 'hadith.db';

  Database? _database;

  Future<void> initialize() async {
    await _openDatabase();
  }

  Future<List<HadithCollectionSummary>> fetchCollections() async {
    final db = await _openDatabase();
    final result = await _queryCollectionMeta(db);

    return result
        .map(
          (row) => HadithCollectionSummary(
            name: _readString(row['collection']),
            hadithCount: _readInt(row['hadith_count']),
            bookCount: _readInt(row['book_count']),
            chapterCount: _readInt(row['chapter_count']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<HadithBook>> fetchBooks(
    String collection, {
    String query = '',
  }) async {
    final db = await _openDatabase();
    final metaResult = await _queryBookMeta(
      db,
      collection: collection,
      query: query,
    );

    return metaResult
        .map(
          (row) => HadithBook(
            collection: _readString(row['collection']),
            bookNumber: _readString(row['book_no']),
            englishName: _readString(row['book_en']),
            arabicName: _readString(row['book_ar']),
            hadithCount: _readInt(row['hadith_count']),
            chapterCount: _readInt(row['chapter_count']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> _queryCollectionMeta(Database db) async {
    try {
      return await db.query(
        'collection_meta',
        orderBy: 'sort_order ASC, collection ASC',
      );
    } catch (_) {
      return db.rawQuery('''
        SELECT
          collection,
          COUNT(*) AS hadith_count,
          COUNT(DISTINCT book_no) AS book_count,
          COUNT(DISTINCT chapter_no) AS chapter_count
        FROM hadiths
        GROUP BY collection
        ORDER BY hadith_count DESC, collection ASC
      ''');
    }
  }

  Future<List<Map<String, Object?>>> _queryBookMeta(
    Database db, {
    required String collection,
    required String query,
  }) async {
    final normalizedQuery = query.trim();

    final whereClauses = <String>['collection = ?'];
    final args = <Object?>[collection];

    if (normalizedQuery.isNotEmpty) {
      whereClauses.add('(book_en LIKE ? OR book_ar LIKE ? OR book_no LIKE ?)');
      final pattern = '%$normalizedQuery%';
      args.addAll([pattern, pattern, pattern]);
    }

    try {
      return await db.query(
        'book_meta',
        where: whereClauses.join(' AND '),
        whereArgs: args,
        orderBy: 'sort_order ASC, book_no ASC',
      );
    } catch (_) {
      return db.rawQuery('''
        SELECT
          collection,
          book_no,
          MAX(book_en) AS book_en,
          MAX(book_ar) AS book_ar,
          COUNT(*) AS hadith_count,
          COUNT(DISTINCT chapter_no) AS chapter_count
        FROM hadiths
        WHERE ${whereClauses.join(' AND ')}
        GROUP BY collection, book_no
        ORDER BY CAST(book_no AS INTEGER), book_no ASC
        ''', args);
    }
  }

  Future<List<Hadith>> fetchHadithsForBook(
    HadithBook book, {
    String query = '',
  }) async {
    final db = await _openDatabase();
    final normalizedQuery = query.trim();

    final whereClauses = <String>['collection = ?', 'book_no = ?'];
    final args = <Object?>[book.collection, book.bookNumber];

    if (normalizedQuery.isNotEmpty) {
      whereClauses.add('''
        (
          english_full LIKE ?
          OR text_en LIKE ?
          OR narrator_en LIKE ?
          OR chapter_en LIKE ?
          OR arabic_full LIKE ?
          OR arabic_matn LIKE ?
        )
      ''');
      final pattern = '%$normalizedQuery%';
      args.addAll([pattern, pattern, pattern, pattern, pattern, pattern]);
    }

    final result = await db.query(
      'hadiths',
      where: whereClauses.join(' AND '),
      whereArgs: args,
      orderBy: 'id ASC',
    );

    return result.map(_mapHadith).toList(growable: false);
  }

  Future<List<Hadith>> searchHadiths(String query, {int limit = 50}) async {
    final db = await _openDatabase();
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => '"${token.replaceAll('"', '""')}"*')
        .join(' ');

    if (tokens.isEmpty) {
      return const [];
    }

    final result = await db.rawQuery(
      '''
      SELECT h.*
      FROM hadith_fts f
      JOIN hadiths h ON h.id = f.rowid
      WHERE hadith_fts MATCH ?
      ORDER BY h.id ASC
      LIMIT ?
      ''',
      [tokens, limit],
    );

    return result.map(_mapHadith).toList(growable: false);
  }

  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _openDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await _ensureDatabaseAvailable();
    _database = await openDatabase(dbPath, readOnly: true);
    return _database!;
  }

  Future<String> _ensureDatabaseAvailable() async {
    final directory = await getApplicationSupportDirectory();
    final dbPath = path.join(directory.path, _databaseName);
    final dbFile = File(dbPath);
    final assetBytes = await rootBundle.load(_assetPath);

    if (!await dbFile.exists() ||
        await dbFile.length() != assetBytes.lengthInBytes) {
      await dbFile.parent.create(recursive: true);
      await dbFile.writeAsBytes(assetBytes.buffer.asUint8List(), flush: true);
    }

    return dbPath;
  }

  Hadith _mapHadith(Map<String, Object?> row) {
    return Hadith(
      id: _readInt(row['id']),
      collection: _readString(row['collection']),
      hadithId: _readString(row['hadith_id']),
      hadithNumberInBook: _readString(row['hadith_no_in_book']),
      bookNumber: _readString(row['book_no']),
      bookNameEnglish: _readString(row['book_en']),
      bookNameArabic: _readString(row['book_ar']),
      chapterNumber: _readString(row['chapter_no']),
      chapterNameEnglish: _readString(row['chapter_en']),
      chapterNameArabic: _readString(row['chapter_ar']),
      narratorEnglish: _readString(row['narrator_en']),
      englishText: _readString(row['text_en']),
      englishFull: _readString(row['english_full']),
      arabicSanad: _readString(row['arabic_sanad']),
      arabicMatn: _readString(row['arabic_matn']),
      arabicFull: _readString(row['arabic_full']),
      reference: _readString(row['ref_raw']),
      inBookReference: _readString(row['in_book_ref_raw']),
      translationReference: _readString(row['trans_ref_raw']),
      url: _readString(row['url']),
    );
  }

  String _readString(Object? value) => value?.toString().trim() ?? '';

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

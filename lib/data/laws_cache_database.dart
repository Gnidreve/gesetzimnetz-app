import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/paragraph_detail.dart';
import '../models/summaries.dart';

class LawsCacheDatabase {
  LawsCacheDatabase._();

  static final LawsCacheDatabase _instance = LawsCacheDatabase._();

  factory LawsCacheDatabase() => _instance;

  static const String _databaseName = 'gesetz_im_netz_cache.db';
  static const int _databaseVersion = 2;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS paragraph_details');
          await db.execute('''
            CREATE TABLE paragraph_details (
              law_code TEXT NOT NULL,
              paragraph_number TEXT NOT NULL,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              PRIMARY KEY (law_code, paragraph_number)
            )
          ''');
        }
      },
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE laws (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_index INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE paragraphs (
        law_code TEXT NOT NULL,
        paragraph_number TEXT NOT NULL,
        title TEXT NOT NULL,
        sort_index INTEGER NOT NULL,
        PRIMARY KEY (law_code, paragraph_number)
      )
    ''');
    await db.execute('''
      CREATE TABLE paragraph_details (
        law_code TEXT NOT NULL,
        paragraph_number TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        PRIMARY KEY (law_code, paragraph_number)
      )
    ''');
  }

  Future<void> replaceLaws(List<LawSummary> laws) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('laws');
      for (var index = 0; index < laws.length; index++) {
        await txn.insert('laws', laws[index].toDbMap(index));
      }
    });
  }

  Future<List<LawSummary>> readLaws() async {
    final db = await database;
    final rows = await db.query('laws', orderBy: 'sort_index ASC');

    return rows.map(LawSummary.fromDb).toList(growable: false);
  }

  Future<void> replaceParagraphs(
    String lawCode,
    List<ParagraphSummary> paragraphs,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'paragraphs',
        where: 'law_code = ?',
        whereArgs: <Object?>[lawCode],
      );
      for (var index = 0; index < paragraphs.length; index++) {
        await txn.insert(
          'paragraphs',
          paragraphs[index].toDbMap(lawCode, index),
        );
      }
    });
  }

  Future<List<ParagraphSummary>> readParagraphs(String lawCode) async {
    final db = await database;
    final rows = await db.query(
      'paragraphs',
      where: 'law_code = ?',
      whereArgs: <Object?>[lawCode],
      orderBy: 'sort_index ASC',
    );

    return rows.map(ParagraphSummary.fromDb).toList(growable: false);
  }

  Future<void> upsertParagraphDetail(
    String lawCode,
    ParagraphDetail detail,
  ) async {
    final db = await database;
    await db.insert(
      'paragraph_details',
      detail.toDbMap(lawCode),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ParagraphDetail?> readParagraphDetail(
    String lawCode,
    String paragraphNumber,
  ) async {
    final db = await database;
    final rows = await db.query(
      'paragraph_details',
      where: 'law_code = ? AND paragraph_number = ?',
      whereArgs: <Object?>[lawCode, paragraphNumber],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ParagraphDetail.fromDb(rows.first);
  }
}

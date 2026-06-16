import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('takapay.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sender TEXT NOT NULL,
  amount TEXT NOT NULL,
  trx_id TEXT NOT NULL,
  raw_body TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  status TEXT NOT NULL,
  error_message TEXT
)
''');
    await db.execute('''
CREATE TABLE debug_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  category TEXT NOT NULL,
  message TEXT NOT NULL,
  is_error INTEGER NOT NULL DEFAULT 0
)
''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS debug_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  category TEXT NOT NULL,
  message TEXT NOT NULL,
  is_error INTEGER NOT NULL DEFAULT 0
)
''');
    }
  }

  Future<int> insertTransaction(TransactionRecord record) async {
    final db = await instance.database;
    return await db.insert('transactions', record.toMap());
  }

  Future<int> updateTransaction(TransactionRecord record) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<List<TransactionRecord>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'timestamp DESC');
    return result.map((json) => TransactionRecord.fromMap(json)).toList();
  }

  Future<void> clearHistory() async {
    final db = await instance.database;
    await db.delete('transactions');
  }

  // Debug Logs methods
  Future<int> insertDebugLog(String category, String message, {bool isError = false}) async {
    try {
      final db = await instance.database;
      return await db.insert('debug_logs', {
        'timestamp': DateTime.now().toIso8601String(),
        'category': category,
        'message': message,
        'is_error': isError ? 1 : 0,
      });
    } catch (e) {
      print('DatabaseHelper insertDebugLog error: $e');
      if (e.toString().contains('no such table')) {
        try {
          final db = await instance.database;
          await db.execute('''
            CREATE TABLE IF NOT EXISTS debug_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp TEXT NOT NULL,
              category TEXT NOT NULL,
              message TEXT NOT NULL,
              is_error INTEGER NOT NULL DEFAULT 0
            )
          ''');
          return await db.insert('debug_logs', {
            'timestamp': DateTime.now().toIso8601String(),
            'category': category,
            'message': message,
            'is_error': isError ? 1 : 0,
          });
        } catch (innerEx) {
          print('Failed to create debug_logs table on insert: $innerEx');
        }
      }
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getDebugLogs({int limit = 200}) async {
    try {
      final db = await instance.database;
      return await db.query(
        'debug_logs',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    } catch (e) {
      print('DatabaseHelper getDebugLogs error: $e');
      if (e.toString().contains('no such table')) {
        try {
          final db = await instance.database;
          await db.execute('''
            CREATE TABLE IF NOT EXISTS debug_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp TEXT NOT NULL,
              category TEXT NOT NULL,
              message TEXT NOT NULL,
              is_error INTEGER NOT NULL DEFAULT 0
            )
          ''');
          return await db.query(
            'debug_logs',
            orderBy: 'timestamp DESC',
            limit: limit,
          );
        } catch (innerEx) {
          print('Failed to create debug_logs table on query: $innerEx');
        }
      }
      return [];
    }
  }

  Future<void> clearDebugLogs() async {
    try {
      final db = await instance.database;
      await db.delete('debug_logs');
    } catch (e) {
      print('DatabaseHelper clearDebugLogs error: $e');
    }
  }
}

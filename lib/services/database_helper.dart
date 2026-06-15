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
      version: 1,
      onCreate: _createDB,
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
}

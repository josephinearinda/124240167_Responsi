import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalUser {
  const LocalUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;
}

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const _databaseName = 'shoppinghub.db';
  Database? _database;

  Future<void> initialize() async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await _openDatabase();
  }

  Future<Database> _openDatabase() async {
    if (_database != null) return _database!;
    final databasePath = path.join(await getDatabasesPath(), _databaseName);
    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE,
            password_hash TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE wishlist (
            user_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            PRIMARY KEY (user_id, product_id),
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
      },
    );
    return _database!;
  }

  String _hashPassword(String password) =>
      sha256.convert(password.codeUnits).toString();

  Future<void> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await _openDatabase();
    await db.insert('users', {
      'name': name.trim(),
      'email': email.trim(),
      'password_hash': _hashPassword(password),
    });
  }

  Future<LocalUser?> validateUser({
    required String email,
    required String password,
  }) async {
    final db = await _openDatabase();
    final users = await db.query(
      'users',
      columns: ['id', 'name', 'email'],
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email.trim(), _hashPassword(password)],
      limit: 1,
    );
    if (users.isEmpty) return null;
    final row = users.first;
    return LocalUser(
      id: row['id'] as int,
      name: row['name'] as String,
      email: row['email'] as String,
    );
  }

  Future<LocalUser?> getUserByEmail(String email) async {
    final db = await _openDatabase();
    final users = await db.query(
      'users',
      columns: ['id', 'name', 'email'],
      where: 'email = ?',
      whereArgs: [email.trim()],
      limit: 1,
    );
    if (users.isEmpty) return null;
    final row = users.first;
    return LocalUser(
      id: row['id'] as int,
      name: row['name'] as String,
      email: row['email'] as String,
    );
  }

  Future<bool> isEmailRegistered(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  Future<Set<int>> getWishlist(int userId) async {
    final db = await _openDatabase();
    final rows = await db.query(
      'wishlist',
      columns: ['product_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((row) => row['product_id'] as int).toSet();
  }

  Future<void> removeFromWishlist(int userId, int productId) async {
    final db = await _openDatabase();
    await db.delete(
      'wishlist',
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
    );
  }

  Future<bool> toggleWishlist(int userId, int productId) async {
    final db = await _openDatabase();
    final rows = await db.query(
      'wishlist',
      columns: ['product_id'],
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await db.delete(
        'wishlist',
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
      );
      return false;
    }
    await db.insert('wishlist', {'user_id': userId, 'product_id': productId});
    return true;
  }
}

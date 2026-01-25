import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DBService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'flutter.db');

    // 👉 คัดลอก DB ครั้งแรกเท่านั้น
    if (!await File(path).exists()) {
      ByteData data = await rootBundle.load('backend/flutter.db');
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes);
    }

    print('✅ USING DB => $path');

    return await openDatabase(
      path,
      version: 1,
    );
  }

  // ---------- AUTH ----------
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<bool> loginAdmin(String email, String password) async {
    final db = await database;

    final result = await db.query(
      'admin_users',
      where: 'email = ? AND password_hash = ? AND is_admin = 1',
      whereArgs: [email, hashPassword(password)],
      limit: 1,
    );

    return result.isNotEmpty;
  }
}

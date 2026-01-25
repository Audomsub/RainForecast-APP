import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class DBService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    // ใช้ชื่อ DB เดิมที่คุณใช้อยู่ (เช่น rainforecast_v2.db หรือ rainforecast_final.db)
    final path = join(dbPath, 'rainforecast_v2.db'); 

    print('✅ DATABASE PATH => $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. Admin Table
        await db.execute('''
          CREATE TABLE admin_users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            is_admin INTEGER DEFAULT 0
          )
        ''');
        await db.insert('admin_users', {
          'email': 'admin@gmail.com',
          'password_hash': hashPassword('123456'),
          'is_admin': 1,
        });

        // 2. Report Categories
        await db.execute('''
          CREATE TABLE report_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon_code INTEGER NOT NULL,
            color_value INTEGER NOT NULL
          )
        ''');

        // ข้อมูล 6 ระดับ
        await db.insert('report_categories', {'name': 'Light Rain', 'icon_code': 0xe197, 'color_value': 0xFF69F0AE});
        await db.insert('report_categories', {'name': 'Moderate Rain', 'icon_code': 0xe6e6, 'color_value': 0xFFFFEB3B});
        await db.insert('report_categories', {'name': 'Mod-Heavy Rain', 'icon_code': 0xe6e5, 'color_value': 0xFFFF9800});
        await db.insert('report_categories', {'name': 'Heavy Rain', 'icon_code': 0xe6e4, 'color_value': 0xFFF44336});
        await db.insert('report_categories', {'name': 'Very Heavy Rain', 'icon_code': 0xe6e7, 'color_value': 0xFF9C27B0});
        await db.insert('report_categories', {'name': 'Extreme Rain', 'icon_code': 0xeb46, 'color_value': 0xFF2196F3});

        // 3. Rain Reports
        await db.execute('''
          CREATE TABLE rain_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            category_id INTEGER NOT NULL,
            timestamp TEXT NOT NULL, 
            description TEXT,
            reporter_name TEXT,
            image_path TEXT, 
            FOREIGN KEY (category_id) REFERENCES report_categories (id) ON DELETE CASCADE
          )
        ''');
        
        print('✅ Database Created!');
      },
    );
  }

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // --- CRUD Functions ---
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('report_categories');
  }

  Future<int> addReport(double lat, double lng, int categoryId, String desc, String reporter, String? imagePath) async {
    final db = await database;
    return await db.insert('rain_reports', {
      'latitude': lat,
      'longitude': lng,
      'category_id': categoryId,
      'timestamp': DateTime.now().toIso8601String(),
      'description': desc,
      'reporter_name': reporter,
      'image_path': imagePath,
    });
  }

  Future<List<Map<String, dynamic>>> getActiveReports() async {
    final db = await database;
    final timeLimit = DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String();
    return await db.rawQuery('''
      SELECT r.*, c.name as cat_name, c.icon_code, c.color_value
      FROM rain_reports r
      JOIN report_categories c ON r.category_id = c.id
      WHERE r.timestamp > ? 
      ORDER BY r.timestamp DESC
    ''', [timeLimit]);
  }

  // --- Admin Functions ---

  Future<List<Map<String, dynamic>>> getAllReportsForAdmin() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT r.*, c.name as cat_name, c.icon_code, c.color_value
      FROM rain_reports r
      JOIN report_categories c ON r.category_id = c.id
      ORDER BY r.timestamp DESC
    ''');
  }

  // ✅ 1. ดึงรายชื่อผู้ใช้ทั้งหมด (คนที่เคยรายงาน)
  Future<List<Map<String, dynamic>>> getUniqueUsers() async {
    final db = await database;
    // ดึงชื่อคนรายงานที่ไม่ซ้ำกัน พร้อมนับจำนวนครั้งที่รายงาน
    return await db.rawQuery('''
      SELECT reporter_name, COUNT(*) as report_count, MAX(timestamp) as last_active
      FROM rain_reports
      GROUP BY reporter_name
      ORDER BY last_active DESC
    ''');
  }

  // ✅ 2. ดึงสถิติรายชั่วโมง (00:00 - 23:00)
  Future<List<Map<String, dynamic>>> getHourlyStats() async {
    final db = await database;
    // Group ตามชั่วโมง (Substr เอาแค่ 11,2 คือตำแหน่ง HH ใน ISO String)
    // หมายเหตุ: SQLite ไม่มีฟังก์ชัน Hour โดยตรงที่ง่ายเหมือน MySQL เลยต้องใช้ substr หรือ strftime
    return await db.rawQuery('''
      SELECT strftime('%H', timestamp) as hour, COUNT(*) as count
      FROM rain_reports
      GROUP BY hour
      ORDER BY hour
    ''');
  }

  Future<int> updateReport(int id, int categoryId, String description) async {
    final db = await database;
    return await db.update('rain_reports', {
      'category_id': categoryId,
      'description': description,
    }, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<int> deleteReport(int id) async {
    final db = await database;
    return await db.delete('rain_reports', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> loginAdmin(String email, String password) async {
    final db = await database;
    final result = await db.query(
      'admin_users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email, hashPassword(password)],
    );
    return result.isNotEmpty;
  }
}
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart'; // จำเป็นสำหรับ Colors และ Icons

class DBService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    // ⚠️ เปลี่ยนชื่อ DB เป็น 'rainforecast_complete.db' เพื่อเริ่มสร้างตารางใหม่ที่สมบูรณ์
    final path = join(dbPath, 'rainforecast_complete.db'); 

    print('✅ DATABASE PATH => $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // --- 1. Admin Table ---
        await db.execute('''
          CREATE TABLE admin_users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            is_admin INTEGER DEFAULT 0
          )
        ''');
        // เพิ่ม Admin เริ่มต้น: admin@gmail.com / 123456
        await db.insert('admin_users', {
          'email': 'admin@gmail.com',
          'password_hash': hashPassword('123456'),
          'is_admin': 1,
        });

        // --- 2. Table ระดับฝน (Report Categories) ---
        await db.execute('''
          CREATE TABLE report_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon_code INTEGER NOT NULL,
            color_value INTEGER NOT NULL
          )
        ''');

        // ✅ เพิ่มข้อมูล 6 ระดับ (Seeding)
        await db.insert('report_categories', {'name': 'Light Rain', 'icon_code': Icons.cloud.codePoint, 'color_value': 0xFF69F0AE}); // เขียว
        await db.insert('report_categories', {'name': 'Moderate Rain', 'icon_code': Icons.grain.codePoint, 'color_value': 0xFFFFEB3B}); // เหลือง
        await db.insert('report_categories', {'name': 'Mod-Heavy Rain', 'icon_code': Icons.shower.codePoint, 'color_value': 0xFFFF9800}); // ส้ม
        await db.insert('report_categories', {'name': 'Heavy Rain', 'icon_code': Icons.umbrella.codePoint, 'color_value': 0xFFF44336}); // แดง
        await db.insert('report_categories', {'name': 'Very Heavy Rain', 'icon_code': Icons.thunderstorm.codePoint, 'color_value': 0xFF9C27B0}); // ม่วง
        await db.insert('report_categories', {'name': 'Extreme Rain', 'icon_code': Icons.tsunami.codePoint, 'color_value': 0xFF2196F3}); // ฟ้า

        // --- 3. Table เก็บรายงาน (Rain Reports) ---
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
        
        print('✅ Database Created: rainforecast_complete.db');
      },
    );
  }

  // ฟังก์ชัน Hash Password
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ==========================================
  // 🌧️ ฟังก์ชันสำหรับ User ทั่วไป
  // ==========================================

  // 1. ดึง Categories มาแสดงใน Dropdown
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('report_categories');
  }

  // 2. บันทึกรายงาน (Create) รองรับรูปภาพ
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

  // 3. ดึงรายงาน Active (30 นาทีล่าสุด)
  Future<List<Map<String, dynamic>>> getActiveReports() async {
    final db = await database;
    // ดึงข้อมูลย้อนหลังไม่เกิน 30 นาที
    final timeLimit = DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String();

    return await db.rawQuery('''
      SELECT r.*, c.name as cat_name, c.icon_code, c.color_value
      FROM rain_reports r
      JOIN report_categories c ON r.category_id = c.id
      WHERE r.timestamp > ? 
      ORDER BY r.timestamp DESC
    ''', [timeLimit]);
  }

  // ==========================================
  // 🛡️ ฟังก์ชันสำหรับ Admin Dashboard
  // ==========================================

  // 4. ดึงรายงานทั้งหมด (Admin) + ✅ แก้บั๊ก ID
  Future<List<Map<String, dynamic>>> getAllReportsForAdmin() async {
    final db = await database;
    // ⚠️ สำคัญ: ตั้งชื่อ r.id เป็น report_id เพื่อไม่ให้ซ้ำกับ c.id
    return await db.rawQuery('''
      SELECT r.id as report_id, r.*, c.name as cat_name, c.icon_code, c.color_value
      FROM rain_reports r
      JOIN report_categories c ON r.category_id = c.id
      ORDER BY r.timestamp DESC
    ''');
  }

  // 5. ดึงรายชื่อผู้ใช้ทั้งหมด (Unique Users)
  Future<List<Map<String, dynamic>>> getUniqueUsers() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT reporter_name, COUNT(*) as report_count, MAX(timestamp) as last_active
      FROM rain_reports
      GROUP BY reporter_name
      ORDER BY last_active DESC
    ''');
  }

  // 6. ดึงสถิติรายชั่วโมง (Hourly Stats)
  Future<List<Map<String, dynamic>>> getHourlyStats() async {
    final db = await database;
    // Group ตามชั่วโมง (HH)
    return await db.rawQuery('''
      SELECT strftime('%H', timestamp) as hour, COUNT(*) as count
      FROM rain_reports
      GROUP BY hour
      ORDER BY hour
    ''');
  }

  // 7. แก้ไขรายงาน (Update)
  Future<int> updateReport(int id, int categoryId, String description) async {
    final db = await database;
    return await db.update('rain_reports', {
      'category_id': categoryId,
      'description': description,
    }, where: 'id = ?', whereArgs: [id]);
  }
  
  // 8. ลบรายงาน (Delete)
  Future<int> deleteReport(int id) async {
    final db = await database;
    return await db.delete('rain_reports', where: 'id = ?', whereArgs: [id]);
  }

  // ฟังก์ชัน Login
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
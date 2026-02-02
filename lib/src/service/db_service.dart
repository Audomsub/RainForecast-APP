import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ 1. Import Supabase

class DBService {
  static Database? _db;
  
  // ✅ 2. เรียกใช้ Client ของ Supabase
  final _supabase = Supabase.instance.client; 

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rainforecast_stable.db'); 
    print('✅ DATABASE PATH => $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // --- สร้างตารางเหมือนเดิม ---
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

        await db.execute('''
          CREATE TABLE report_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon_code INTEGER NOT NULL,
            color_value INTEGER NOT NULL
          )
        ''');

        await db.insert('report_categories', {'name': 'Light Rain', 'icon_code': 0xe197, 'color_value': 0xFF69F0AE});
        await db.insert('report_categories', {'name': 'Moderate Rain', 'icon_code': 0xe6e6, 'color_value': 0xFFFFEB3B});
        await db.insert('report_categories', {'name': 'Mod-Heavy Rain', 'icon_code': 0xe6e5, 'color_value': 0xFFFF9800});
        await db.insert('report_categories', {'name': 'Heavy Rain', 'icon_code': 0xe6e4, 'color_value': 0xFFF44336});
        await db.insert('report_categories', {'name': 'Very Heavy Rain', 'icon_code': 0xe6e7, 'color_value': 0xFF9C27B0});
        await db.insert('report_categories', {'name': 'Extreme Rain', 'icon_code': 0xeb46, 'color_value': 0xFF2196F3});

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

  // ✅ 3. แก้ไข addReport ให้ส่งทั้ง 2 ทาง
  Future<void> addReport(double lat, double lng, int categoryId, String desc, String reporter, String? imagePath) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    // 3.1 บันทึกลงเครื่อง (SQLite)
    await db.insert('rain_reports', {
      'latitude': lat,
      'longitude': lng,
      'category_id': categoryId,
      'timestamp': timestamp,
      'description': desc,
      'reporter_name': reporter,
      'image_path': imagePath, 
    });

    // 3.2 ส่งขึ้น Supabase (Cloud)
    try {
      await _supabase.from('rain_reports').insert({
        'latitude': lat,
        'longitude': lng,
        'category_id': categoryId,
        'timestamp': timestamp,
        'description': desc,
        'reporter_name': reporter,
        // หมายเหตุ: image_path ที่เป็น path ในเครื่องจะส่งไปไม่ได้
        // ถ้าจะทำรูปออนไลน์ต้องอัพโหลดผ่าน Supabase Storage ก่อน
      });
      print("☁️ Sent to Supabase successfully");
    } catch (e) {
      print("❌ Supabase upload failed: $e");
      // ถ้าเน็ตหลุด ก็ไม่เป็นไร เพราะเซฟลง SQLite แล้ว
    }
  }

  // ✅ 4. เพิ่มฟังก์ชันดึงข้อมูลจาก Supabase
  Future<List<Map<String, dynamic>>> getSupabaseReports() async {
    try {
      // ดึงข้อมูลพร้อม Join ตาราง Categories
      final response = await _supabase
          .from('rain_reports')
          .select('*, report_categories(name, icon_code, color_value)')
          .gt('timestamp', DateTime.now().subtract(const Duration(hours: 24)).toIso8601String())
          .order('timestamp', ascending: false);

      // ตรวจสอบว่า response เป็น List หรือไม่
      final List<dynamic> data = response as List<dynamic>;
      
      // ✅ จุดที่แก้: ใช้ Map<String, dynamic>.from() เพื่อแปลง Type ของข้อมูลให้ถูกต้อง
      return data.map<Map<String, dynamic>>((item) {
        // แปลง item แต่ละตัวให้เป็น Map<String, dynamic> อย่างปลอดภัย
        final safeItem = Map<String, dynamic>.from(item as Map);
        
        // จัดการกับข้อมูลที่ Join มา (report_categories)
        final cat = safeItem['report_categories'];
        
        return {
          ...safeItem,
          'cat_name': cat != null ? cat['name'] : 'Unknown',
          'icon_code': cat != null ? cat['icon_code'] : 0xe197, 
          'color_value': cat != null ? cat['color_value'] : 0xFF9E9E9E, 
        };
      }).toList();

    } catch (e) {
      print("⚠️ Fetch Supabase Error: $e");
      return []; // คืนค่าว่างถ้าดึงไม่ได้
    }
  }

  // ฟังก์ชันดึงจาก SQLite (Offline)
  Future<List<Map<String, dynamic>>> getLocalReports() async {
    final db = await database;
    final timeLimit = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();

    return await db.rawQuery('''
      SELECT r.*, c.name as cat_name, c.icon_code, c.color_value
      FROM rain_reports r
      JOIN report_categories c ON r.category_id = c.id
      WHERE r.timestamp > ? 
      ORDER BY r.timestamp DESC
    ''', [timeLimit]);
  }

  // --- Admin Functions ---
  // (ส่วน Admin ใช้ของเดิม หรือจะเปลี่ยนไปดึงจาก Supabase ก็ได้ในอนาคต)
  Future<List<Map<String, dynamic>>> getAllReportsForAdmin() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT r.id as report_id, r.*, c.name as cat_name, c.icon_code, c.color_value
      FROM rain_reports r
      JOIN report_categories c ON r.category_id = c.id
      ORDER BY r.timestamp DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getUniqueUsers() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT reporter_name, COUNT(*) as report_count, MAX(timestamp) as last_active
      FROM rain_reports
      GROUP BY reporter_name
      ORDER BY last_active DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getHourlyStats() async {
    final db = await database;
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
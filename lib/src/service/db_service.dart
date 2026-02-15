import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; 
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

// ✅ กำหนด URL ของ Backend
final String backendUrl = 'https://rainforecast-app.onrender.com/api';

class DBService {
  static Database? _db;
  final _supabase = Supabase.instance.client; 

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  // --- 1. การจัดการฐานข้อมูลภายใน (Local SQLite) ---

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rainforecast_stable.db'); 
    debugPrint('✅ DATABASE PATH => $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // ตารางสำหรับ Admin
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

        // ตารางหมวดหมู่ความรุนแรงของฝน
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

        // ตารางการรายงานสภาพอากาศ
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

  // --- 2. การจัดการข้อมูลการรายงาน (Reports) ---

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('report_categories');
  }

  Future<void> addReport(double lat, double lng, int categoryId, String desc, String reporter, String? imagePath) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    // บันทึกลง Local
    await db.insert('rain_reports', {
      'latitude': lat,
      'longitude': lng,
      'category_id': categoryId,
      'timestamp': timestamp,
      'description': desc,
      'reporter_name': reporter,
      'image_path': imagePath, 
    });

    // อัปโหลดขึ้น Supabase
    try {
      await _supabase.from('rain_reports').insert({
        'latitude': lat,
        'longitude': lng,
        'category_id': categoryId,
        'timestamp': timestamp,
        'description': desc,
        'reporter_name': reporter,
      });
      debugPrint("☁️ Sent to Supabase successfully");
    } catch (e) {
      debugPrint("❌ Supabase upload failed: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getSupabaseReports() async {
    try {
      final response = await _supabase
          .from('rain_reports')
          .select('*, report_categories(name, icon_code, color_value)')
          .gt('timestamp', DateTime.now().subtract(const Duration(hours: 24)).toIso8601String())
          .order('timestamp', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.map<Map<String, dynamic>>((item) {
        final safeItem = Map<String, dynamic>.from(item as Map);
        final cat = safeItem['report_categories'];
        return {
          ...safeItem,
          'cat_name': cat != null ? cat['name'] : 'Unknown',
          'icon_code': cat != null ? cat['icon_code'] : 0xe197, 
          'color_value': cat != null ? cat['color_value'] : 0xFF9E9E9E, 
        };
      }).toList();

    } catch (e) {
      debugPrint("⚠️ Fetch Supabase Error: $e");
      return [];
    }
  }

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

  // --- 3. ฟังก์ชันสำหรับ Admin (Admin Functions) ---

  Future<bool> loginAdmin(String email, String password) async {
    final db = await database;
    final result = await db.query(
      'admin_users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email, hashPassword(password)],
    );
    return result.isNotEmpty;
  }

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

  // --- 4. สถิติและระบบ Online (Traffic Stats) ---

  Future<List<Map<String, dynamic>>> getTrafficStats() async {
    try {
      final response = await _supabase
          .from('online_stats')
          .select('timestamp, user_count')
          .order('timestamp', ascending: true);
      
      return (response as List).map((item) {
        final time = DateTime.parse(item['timestamp']).toLocal();
        return {
          'timestamp': item['timestamp'],
          'hour': time.hour.toString().padLeft(2, '0'),
          'user_count': item['user_count'] ?? 0
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> sendHeartbeat(String deviceId) async {
    try {
      final url = Uri.parse('$backendUrl/admin/track-online'); 
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': deviceId}),
      );
    } catch (error) {
      debugPrint("💓 Heartbeat Error: $error"); 
    }
  }

  Future<int> getOnlineCount() async {
    try {
      final url = Uri.parse('$backendUrl/admin/online-count'); 
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['online_count']; 
      }
    } catch (error) {
      debugPrint("👥 Online Count Error: $error");
    }
    return 0;
  }

  // --- 5. การจัดการประวัติ Radar (Radar History) ---

  // ✅ ดึงประวัติ Radar ผ่าน API เส้น /api/radar/history
  Future<List<Map<String, dynamic>>> getRadarHistory() async {
    try {
      final url = Uri.parse('$backendUrl/radar/history');
      debugPrint("📡 Fetching Radar History from: $url");
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          // คืนค่ารายการประวัติรูปภาพจาก Backend
          return List<Map<String, dynamic>>.from(json['data']);
        }
      } else {
        debugPrint("❌ API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("📡 Radar History Connection Error: $e");
    }
    return [];
  }
}
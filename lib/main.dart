import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Imports
import 'package:rainforecast_app/src/appbar/dropdown-menu.dart';
import 'package:rainforecast_app/src/appbar/menuAlert.dart';
import 'package:rainforecast_app/src/map/mainmap.dart';
import 'package:rainforecast_app/src/legend/legendBar.dart';
import 'package:rainforecast_app/src/legend/legendPopuo.dart';
import 'package:rainforecast_app/src/popup/alertPopup.dart';
import 'package:rainforecast_app/src/popup/weatherPopup.dart';
// import 'package:rainforecast_app/src/login/login.dart'; // ❌ ไม่ได้ใช้แล้ว comment ออกได้

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 🎨 Theme Minimalist
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF6C63FF),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
        // ตั้งค่า Input ทั่วไป
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
      home: const Homepage(),
    );
  }
}

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final TextEditingController _searchController = TextEditingController();

  bool _showLegend = false;
  bool _showWeatherPopup = false;
  bool _showAlertPopup = false;
  String _searchText = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchLocation(String keyword) {
    debugPrint("Search keyword: $keyword");
  }

  // ❌ ลบฟังก์ชัน _openAdminLogin ออกแล้ว เพราะไม่มีปุ่มให้กด

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // --- 1. Map ---
          Positioned.fill(
            child: MainMap(searchText: _searchText),
          ),

          // --- 2. Search Bar (แบบโปร่งใส ไม่มีกรอบหลัง) ---
          Positioned(
            top: 60,
            left: 20,
            right: 90, 
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95), // พื้นหลังปุ่มค้นหาอยู่ที่นี่
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  // ✅ ปิด filled เพื่อไม่ให้มีกล่องสี่เหลี่ยมซ้อน
                  filled: false, 
                  hintText: 'Search Location...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFF6C63FF)),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.white, size: 20),
                      onPressed: () {
                        final value = _searchController.text;
                        if (value.isNotEmpty) {
                          setState(() => _searchText = value);
                          _searchLocation(value);
                          FocusScope.of(context).unfocus();
                        }
                      },
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onSubmitted: (value) {
                  setState(() => _searchText = value);
                  _searchLocation(value);
                },
              ),
            ),
          ),

          // --- 3. Menu (ขวาบน) ---
          Positioned(
            top: 60,
            right: 20,
            child: MapMenu(
              onLegendToggle: () {
                setState(() {
                  _showLegend = !_showLegend;
                  if (_showLegend) {
                    _showWeatherPopup = false;
                    _showAlertPopup = false;
                  }
                });
              },
            ),
          ),

          // ❌ ลบ Positioned ของปุ่ม Admin ออกไปแล้วตรงนี้

          // --- 4. Left Buttons ---
          Positioned(
            top: 150,
            left: 20,
            child: LeftButtons(
              onWeatherTap: () {
                setState(() {
                  _showWeatherPopup = !_showWeatherPopup;
                  if (_showWeatherPopup) {
                    _showLegend = false;
                    _showAlertPopup = false;
                  }
                });
              },
              onNotificationTap: () {
                setState(() {
                  _showAlertPopup = !_showAlertPopup;
                  if (_showAlertPopup) {
                    _showLegend = false;
                    _showWeatherPopup = false;
                  }
                });
              },
            ),
          ),

          // --- Legend Bar ---
          const Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: RainLegendBar(),
          ),

          // --- Popups ---
          if (_showLegend)
            Positioned(
              top: 130,
              right: 80,
              child: LegendPopup(
                onClose: () => setState(() => _showLegend = false),
              ),
            ),

          if (_showWeatherPopup)
            WeatherPopup(
              onClose: () => setState(() => _showWeatherPopup = false),
            ),

          if (_showAlertPopup)
            AlertPopup(
              onClose: () => setState(() => _showAlertPopup = false),
            ),
        ],
      ),
    );
  }
}
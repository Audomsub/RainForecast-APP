import 'dart:io';
import 'dart:convert'; // เพิ่ม
import 'dart:async';   // เพิ่ม
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // เพิ่ม
import 'package:latlong2/latlong.dart';        // เพิ่ม
import 'package:http/http.dart' as http;       // เพิ่ม
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Imports
import 'package:rainforecast_app/src/appbar/dropdown-menu.dart';
import 'package:rainforecast_app/src/appbar/menuAlert.dart';
import 'package:rainforecast_app/src/map/mainmap.dart';
import 'package:rainforecast_app/src/legend/legendBar.dart';
import 'package:rainforecast_app/src/legend/legendPopuo.dart';
import 'package:rainforecast_app/src/popup/alertPopup.dart';
import 'package:rainforecast_app/src/popup/weatherPopup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Supabase.initialize(
    url: 'https://okopzoltzofgefsihcvb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9rb3B6b2x0em9mZ2Vmc2loY3ZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyMjg3ODYsImV4cCI6MjA4NDgwNDc4Nn0.lcFvT2doqDsDlru5mhkrDcG1dzEdRUCpkAFMqq4futw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF6C63FF),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey),
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
  // ✅ สร้าง MapController ที่นี่ เพื่อให้ควบคุมแผนที่ได้จาก Search Bar
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _showLegend = false;
  bool _showWeatherPopup = false;
  bool _showAlertPopup = false;
  bool _isLoading = false; // สถานะการโหลดขณะค้นหา

  String _searchText = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅✅✅ ฟังก์ชันค้นหา (Logic จาก search.dart นำมาใส่ที่นี่) ✅✅✅
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ด
    setState(() => _isLoading = true);

    try {
      // 1. ตรวจสอบว่าเป็นพิกัด (Lat, Lng) หรือไม่
      final RegExp coordRegExp = RegExp(r'^\s*([-+]?\d*\.?\d+)\s*[,\s]\s*([-+]?\d*\.?\d+)\s*$');
      final match = coordRegExp.firstMatch(query);

      if (match != null) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);

        if (lat != null && lng != null) {
          _moveToLocation(lat, lng);
          setState(() => _isLoading = false);
          return;
        }
      }

      // 2. ถ้าไม่ใช่พิกัด ให้ค้นหาชื่อสถานที่ผ่าน Photon API
      // ใช้ API ของ Komoot Photon (OpenStreetMap Data)
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse('https://photon.komoot.io/api/?q=$encodedQuery&limit=1&lang=th'); 

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List;

        if (features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          final coords = geometry['coordinates']; // [lng, lat]
          final double lng = coords[0];
          final double lat = coords[1];
          
          _moveToLocation(lat, lng);
        } else {
          _showSnackBar('ไม่พบสถานที่: "$query"');
        }
      } else {
        _showSnackBar('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _moveToLocation(double lat, double lng) {
    // สั่งย้ายแผนที่ไปที่จุดนั้น
    _mapController.move(LatLng(lat, lng), 13.0);
    // _searchController.clear(); // ล้างคำค้นหา (ถ้าต้องการ)
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          /// ---------------- MAP ----------------
          Positioned.fill(
            child: MainMap(
              searchText: _searchText,
              // mapController: _mapController, // ✅ ส่ง Controller ไปให้ MainMap ใช้
            ),
          ),

          /// ---------------- SEARCH BAR ----------------
          Positioned(
            top: 60,
            left: 20,
            right: 90,
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
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
                  hintText: 'Search Location...',
                  prefixIcon: _isLoading 
                    ? const Padding( // แสดง Loading ถ้ากำลังค้นหา
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF6C63FF),
                      ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C63FF),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 20,
                        ),
                        // ✅ เรียกฟังก์ชันค้นหาเมื่อกดปุ่ม
                        onPressed: _performSearch,
                      ),
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                // ✅ เรียกฟังก์ชันค้นหาเมื่อกด Enter
                onSubmitted: (_) => _performSearch(),
              ),
            ),
          ),

          /// ---------------- MENU ----------------
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

          /// ---------------- LEFT BUTTONS ----------------
          // Positioned(
          //   top: 150,
          //   left: 20,
          //   child: LeftButtons(
          //     onWeatherTap: () {
          //       setState(() {
          //         _showWeatherPopup = !_showWeatherPopup;
          //         if (_showWeatherPopup) {
          //           _showLegend = false;
          //           _showAlertPopup = false;
          //         }
          //       });
          //     },
          //     onNotificationTap: () {
          //       setState(() {
          //         _showAlertPopup = !_showAlertPopup;
          //         if (_showAlertPopup) {
          //           _showLegend = false;
          //           _showWeatherPopup = false;
          //         }
          //       });
          //     },
          //   ),
          // ),

          /// ---------------- LEGEND BAR ----------------
          const Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: RainLegendBar(),
          ),

          /// ---------------- POPUPS ----------------
          if (_showLegend)
            Positioned(
              top: 130,
              right: 80,
              child: LegendPopup(
                onClose: () =>
                    setState(() => _showLegend = false),
              ),
            ),

          if (_showWeatherPopup)
            WeatherPopup(
              title: "Weather Forecast",
              message: "General weather information",
              color: const Color(0xFF6C63FF),
              onClose: () =>
                  setState(() => _showWeatherPopup = false),
            ),

          if (_showAlertPopup)
            AlertPopup(
              onClose: () =>
                  setState(() => _showAlertPopup = false),
            ),
        ],
      ),
    );
  }
}
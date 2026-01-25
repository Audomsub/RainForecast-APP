import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rainforecast_app/src/appbar/dropdown-menu.dart';
import 'package:rainforecast_app/src/appbar/menuAlert.dart';
import 'package:rainforecast_app/src/map/mainmap.dart';
import 'package:rainforecast_app/src/legend/legendBar.dart';
import 'package:rainforecast_app/src/legend/legendPopuo.dart';
import 'package:rainforecast_app/src/popup/alertPopup.dart';
import 'package:rainforecast_app/src/popup/weatherPopup.dart';
import 'package:rainforecast_app/src/login/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔐 Initialize Supabase
  await Supabase.initialize(
    url: 'https://okopzoltzofgefsihcvb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9rb3B6b2x0em9mZ2Vmc2loY3ZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyMjg3ODYsImV4cCI6MjA4NDgwNDc4Nn0.lcFvT2doqDsDlru5mhkrDcG1dzEdRUCpkAFMqq4futw',
  );
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Homepage(),
    );
  }
}

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  bool _showLegend = false;
  bool _showWeatherPopup = false;
  bool _showAlertPopup = false;
  String _searchText = "";

  void _searchLocation(String keyword) {
    debugPrint("Search keyword: $keyword");
  }

  // ================== เปิดหน้า Login ==================
  void _openAdminLogin() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: AdminLoginOverlay(),
      ),
    );
  }
  // ====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- 1. Map ---
          Positioned.fill(
            child: MainMap(
              searchText: _searchText,
            ),
          ),

          // --- 2. Search Bar ---
          Positioned(
            top: 50,
            left: 20,
            right: 80,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search Location...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
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
            top: 50,
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

          // --- 🔐 ปุ่ม Admin Login (ซ้ายล่าง) ---
          Positioned(
            bottom: 100,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'admin',
              backgroundColor: Colors.red,
              onPressed: _openAdminLogin,
              child: const Icon(Icons.admin_panel_settings),
            ),
          ),

          // --- 4. Left Buttons ---
          Positioned(
            top: 180,
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
            bottom: 30,
            left: 20,
            right: 20,
            child: RainLegendBar(),
          ),

          if (_showLegend)
            Positioned(
              top: 120,
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Imports
import 'package:rainforecast_app/src/appbar/dropdown-menu.dart';
import 'package:rainforecast_app/src/appbar/menuAlert.dart'; // สำหรับ LeftButtons
import 'package:rainforecast_app/src/map/mainmap.dart';
import 'package:rainforecast_app/src/legend/legendBar.dart';
import 'package:rainforecast_app/src/legend/legendPopuo.dart'; // แก้ชื่อไฟล์เป็น legendPopup.dart หากจำเป็น
import 'package:rainforecast_app/src/popup/alertPopup.dart';
import 'package:rainforecast_app/src/popup/weatherPopup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ตั้งค่า Database สำหรับ Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // เริ่มต้น Supabase
  await Supabase.initialize(
    url: 'https://okopzoltzofgefsihcvb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9rb3B6b2x0em9mZ2Vmc2loY3ZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyMjg3ODYsImV4cCI6MjA4NDgwNDc4Nn0.lcFvT2doqDsDlru5mhkrDcG1dzEdRUCpkAFMqq4futw',
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
  // สถานะการแสดงผล Popup ต่างๆ
  bool _showLegend = false;
  bool _showWeatherPopup = false;
  bool _showAlertPopup = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // ป้องกัน UI ขยับเมื่อคีย์บอร์ดขึ้น
      body: Stack(
        children: [
          /// ---------------- MAP & SEARCH BAR ----------------
          /// เรียกใช้ MainMap ได้เลย (Search Bar และ MapController อยู่ข้างในแล้ว)
          const Positioned.fill(
            child: MainMap(),
          ),

          /// ---------------- MENU (ขวาบน) ----------------
          Positioned(
            top: 60,
            right: 20,
            child: MapMenu(
              onLegendToggle: () {
                setState(() {
                  _showLegend = !_showLegend;
                  // ปิด Popup อื่นเมื่อเปิด Legend
                  if (_showLegend) {
                    _showWeatherPopup = false;
                    _showAlertPopup = false;
                  }
                });
              },
            ),
          ),

          /// ---------------- LEFT BUTTONS (ซ้ายบน) ----------------
          // Positioned(
          //   top: 150, // วางต่ำลงมาจาก Search Bar
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

          // /// ---------------- LEGEND BAR (แถบล่าง) ----------------
          // const Positioned(
          //   bottom: 40,
          //   left: 20,
          //   right: 20,
          //   child: RainLegendBar(),
          // ),

          /// ---------------- POPUPS (แสดงซ้อนทับเมื่อเปิด) ----------------
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
              title: "Weather Forecast",
              message: "General weather information",
              color: const Color(0xFF6C63FF),
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
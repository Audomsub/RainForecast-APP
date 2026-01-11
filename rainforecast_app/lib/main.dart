import 'package:flutter/material.dart';

// --- Imports ไฟล์ต่างๆ ---
import 'package:rainforecast_app/src/appbar/dropdown-menu.dart';
import 'package:rainforecast_app/src/appbar/menuAlert.dart';
import 'package:rainforecast_app/src/map/mainmap.dart';
import 'package:rainforecast_app/src/map/optionmap.dart';
import 'package:rainforecast_app/src/legend/legendBar.dart';
import 'package:rainforecast_app/src/legend/legendPopuo.dart';
import 'package:rainforecast_app/src/popup/alertPopup.dart';
import 'package:rainforecast_app/src/popup/weatherPopup.dart';
void main() {
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
  // สถานะสำหรับโชว์ Legend (ตารางสี)
  bool _showLegend = false;
  
  // สถานะ Popup สภาพอากาศ (ก้อนเมฆ)
  bool _showWeatherPopup = false; 

  // สถานะ Popup แจ้งเตือน (กระดิ่ง) <--- เพิ่มตัวนี้
  bool _showAlertPopup = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- 1. แผนที่ ---
          Positioned.fill(
            child: const MainMap(),
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
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search Location...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // --- 3. ปุ่มเมนู (ขวาบน) ---
          Positioned(
            top: 50,
            right: 20,
            child: MapMenu(
              onLegendToggle: () {
                setState(() {
                  _showLegend = !_showLegend;
                  // ถ้าเปิด Legend ให้ปิด Popup อื่นๆ ทั้งหมด
                  if (_showLegend) {
                    _showWeatherPopup = false;
                    _showAlertPopup = false;
                  }
                });
              },
            ),
          ),

          // --- 4. ปุ่มเสริมด้านซ้าย (LeftButtons) ---
          Positioned(
            top: 180,
            left: 20,
            child: LeftButtons(
              // ปุ่มเมฆ
              onWeatherTap: () {
                setState(() {
                  _showWeatherPopup = !_showWeatherPopup;
                  // ปิดอันอื่น ถ้าเปิดอันนี้
                  if (_showWeatherPopup) {
                    _showLegend = false;
                    _showAlertPopup = false;
                  }
                });
              },
              // ปุ่มกระดิ่ง (Notification) <--- แก้ไขตรงนี้
              onNotificationTap: () {
                setState(() {
                  _showAlertPopup = !_showAlertPopup; // สลับ เปิด/ปิด
                  // ปิดอันอื่น ถ้าเปิดอันนี้
                  if (_showAlertPopup) {
                    _showLegend = false;
                    _showWeatherPopup = false;
                  }
                });
              },
            ),
          ),

          // --- 5. ปุ่มควบคุมแผนที่ (ขวาล่าง) ---
          Positioned(
            bottom: 100,
            right: 20,
            child: MapControlBar(
              onZoomIn: () {},
              onZoomOut: () {},
              onCurrentLocation: () {},
            ),
          ),

          // --- 6. แถบสี (ล่างสุด) ---
          const Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: RainLegendBar(),
          ),

          // --- 7. Legend Popup (ตารางสี) ---
          if (_showLegend)
            Positioned(
              top: 120,
              right: 80,
              child: LegendPopup(
                onClose: () => setState(() => _showLegend = false),
              ),
            ),

          // --- 8. Weather Popup (สภาพอากาศ) ---
          if (_showWeatherPopup)
            Container(
              color: Colors.black.withOpacity(0.3), 
              child: WeatherPopup(
                onClose: () => setState(() => _showWeatherPopup = false),
              ),
            ),

          // --- 9. Alert Popup (แจ้งเตือน 10 min) --- <--- เพิ่มส่วนนี้
          if (_showAlertPopup)
            Container(
              color: Colors.black.withOpacity(0.3), // พื้นหลังจางๆ
              child: AlertPopup(
                onClose: () => setState(() => _showAlertPopup = false),
              ),
            ),
        ],
      ),
    );
  }
}
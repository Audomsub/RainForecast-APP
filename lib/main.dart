import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/appbar/dropdown-menu.dart';
import 'package:rainforecast_app/src/appbar/menuAlert.dart';
import 'package:rainforecast_app/src/map/mainmap.dart';
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
  bool _showLegend = false;
  bool _showWeatherPopup = false;
  bool _showAlertPopup = false;
  String _searchText = "";

  void _searchLocation(String keyword) {
    debugPrint("Search keyword: $keyword");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- 1. แผนที่ (ปุ่มซูมจะอยู่ในไฟล์นี้ตัวเดียวแล้ว) ---
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

          // --- 3. ปุ่มเมนู (ขวาบน) ---
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

          // --- 4. ปุ่มเสริมด้านซ้าย ---
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
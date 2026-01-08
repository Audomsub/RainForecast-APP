import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/appbar/bar1.dart';
import 'package:rainforecast_app/src/map/mainmap.dart';
import 'package:rainforecast_app/src/appbar/dropdown-menu.dart';

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

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const Bar1(),
      // ใช้ Stack เพื่อซ้อนเลเยอร์
      body: Stack(
        children: [
          // ชั้นล่างสุด: แผนที่ (เต็มจอ)
          Positioned.fill(
            child: const MainMap(),
          ),

          // ชั้นบน: ปุ่มเมนู Dropdown
          // Positioned ใช้กำหนดตำแหน่ง (บน, ซ้าย, ขวา, ล่าง)
          Positioned(
            top: 120, // ให้ห่างจากด้านบน 120 (หลบ AppBar)
            left: 20, // ให้ห่างจากซ้าย 20
            child: const MapMenu(),
          ),
        ],
      ),
    );
  }
}
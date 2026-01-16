import 'package:flutter/material.dart';

import '../login/login.dart';
import '../map/map_with_login.dart';

class MapMenu extends StatefulWidget {
  // 1. เพิ่มตัวแปรรับฟังก์ชัน Callback
  final VoidCallback onLegendToggle;

  const MapMenu({
    super.key,
    required this.onLegendToggle, // 2. บังคับให้ส่งค่านี้มาตอนเรียกใช้
  });

  @override
  State<MapMenu> createState() => _MapMenuState();
}

class _MapMenuState extends State<MapMenu> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        
        // --- 1. ตอนเมนูปิด (แสดงปุ่ม Hamburger) ---
        if (!_isOpen)
          InkWell(
            onTap: () {
              setState(() {
                _isOpen = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 30),
            ),
          ),

        // --- 2. ตอนเมนูเปิด (แสดงรายการปุ่ม) ---
        if (_isOpen)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                // ปุ่ม Settings
                IconButton(
                  onPressed: () {
                     print("กด Settings");
                  },
                  icon: const Icon(Icons.settings, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 10),
                
                // ปุ่ม User / Login
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapWithLogin(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.manage_accounts,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                // --- ปุ่มตกใจ (!) สำหรับแสดง Legend ---
                IconButton(
                  onPressed: () {
                    // 3. เรียกใช้ฟังก์ชันที่ส่งมาจาก Homepage
                    widget.onLegendToggle();
                    
                    // (Optional) ถ้าต้องการให้กดแล้วเมนูหุบเก็บเข้าไปด้วย ให้เปิดบรรทัดล่างนี้ครับ
                    // setState(() => _isOpen = false); 
                  },
                  icon: const Icon(Icons.priority_high, color: Colors.white, size: 30),
                ),
                // ------------------------------------

                // ปุ่ม Close (X)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isOpen = false;
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.white, size: 35),
                ),

              ],
            ),
          ),
      ],
    );
  }
}
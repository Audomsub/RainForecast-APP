import 'package:flutter/material.dart';


class MapMenu extends StatefulWidget {
  const MapMenu({super.key});

  @override
  State<MapMenu> createState() => _MapMenuState();
}

class _MapMenuState extends State<MapMenu> {
  // ตัวแปรเช็คว่าเปิดเมนูอยู่ไหม
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      // จัดให้ชิดซ้าย หรือ ขวา ตามต้องการ
      crossAxisAlignment: CrossAxisAlignment.start, 
      mainAxisSize: MainAxisSize.min, // ให้ขนาดพอดีกับเนื้อหา
      children: [
        
        // 1. ถ้าเมนูปิดอยู่ (_isOpen = false) ให้แสดงปุ่ม Hamburger
        if (!_isOpen)
          InkWell(
            onTap: () {
              setState(() {
                _isOpen = true; // สั่งเปิด
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[600], // สีพื้นหลังปุ่ม
                borderRadius: BorderRadius.circular(10), // มุมโค้ง
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 30),
            ),
          ),

        // 2. ถ้าเมนูเปิดอยู่ (_isOpen = true) ให้แสดงแผงปุ่มยาวๆ
        if (_isOpen)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[600], // สีพื้นหลังแถบ
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                // ปุ่ม Settings
                IconButton(
                  onPressed: () {
                     // ใส่โค้ดไปหน้าตั้งค่า
                     print("กด Settings");
                  },
                  icon: const Icon(Icons.settings, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 10),
                
                // ปุ่ม User
                IconButton(
                  onPressed: () {
                     print("กด เข้าสู่ระบบแอดมิน");
                  },
                  icon: const Icon(Icons.manage_accounts, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 20),
                
                IconButton(
                  onPressed: () {
                    print("กด ลีเจ้น");
                  },
                  icon: const Icon(Icons.priority_high, color: Colors.white, size: 30),
                ),
                // ปุ่ม Close (X)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isOpen = false; // สั่งปิดกลับไปเป็นปุ่มเดิม
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
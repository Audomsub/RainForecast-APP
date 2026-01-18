import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login/login.dart';
import '../map/map_with_login.dart';

class MapMenu extends StatefulWidget {
  final VoidCallback onLegendToggle;

  const MapMenu({
    super.key,
    required this.onLegendToggle,
  });

  @override
  State<MapMenu> createState() => _MapMenuState();
}

class _MapMenuState extends State<MapMenu> {
  bool _isOpen = false;
  bool _isNotifyOn = true; 
  
  // กำหนดขนาดความกว้างคงที่ไว้ที่ 54.0 (เพื่อให้เท่ากันทั้งตอนเปิดและปิด)
  final double _fixedWidth = 54.0;

  @override
  void initState() {
    super.initState();
    _loadNotifySetting(); 
  }

  // โหลดค่าจากหน่วยความจำ
  Future<void> _loadNotifySetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotifyOn = prefs.getBool('isNotifyOn') ?? true;
    });
  }

  // สลับค่าและบันทึก
  Future<void> _toggleNotify() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotifyOn = !_isNotifyOn;
      prefs.setBool('isNotifyOn', _isNotifyOn);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        
        // --- 1. ตอนเมนูปิด (ปุ่ม Hamburger) ---
        if (!_isOpen)
          InkWell(
            onTap: () => setState(() => _isOpen = true),
            child: Container(
              width: _fixedWidth,  // ล็อคความกว้าง 54
              height: _fixedWidth, // ล็อคความสูง 54 ให้เป็นสี่เหลี่ยมจัตุรัส
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 30),
            ),
          ),

        // --- 2. ตอนเมนูเปิด (Dropdown) ---
        if (_isOpen)
          Container(
            width: _fixedWidth, // ล็อคความกว้าง 54 เท่ากับตอนปิดเป๊ะๆ
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ปุ่มแจ้งเตือน
                _buildMenuButton(
                  icon: _isNotifyOn ? Icons.notifications_active : Icons.notifications_off,
                  color: _isNotifyOn ? Colors.yellow : Colors.white,
                  onTap: _toggleNotify,
                ),
                
                // ปุ่ม Login/User
                _buildMenuButton(
                  icon: Icons.manage_accounts,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MapWithLogin()),
                    );
                  },
                ),

                // ปุ่ม Legend (!)
                _buildMenuButton(
                  icon: Icons.priority_high,
                  onTap: widget.onLegendToggle,
                ),
                
                // เส้นคั่น
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(color: Colors.white24, height: 16, thickness: 1),
                ),

                // ปุ่มปิด (X)
                _buildMenuButton(
                  icon: Icons.close,
                  size: 32,
                  onTap: () => setState(() => _isOpen = false),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- ฟังก์ชันสร้างปุ่มเมนูให้มีขนาดกึ่งกลางและเท่ากันทุกปุ่ม ---
  Widget _buildMenuButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    double size = 28,
  }) {
    return SizedBox(
      width: _fixedWidth, // บังคับความกว้างปุ่มให้เท่ากับ Container หลัก
      height: 48,         // กำหนดความสูงของแต่ละแถวให้พอดี
      child: IconButton(
        padding: EdgeInsets.zero, // ลบ padding ของระบบเพื่อให้ icon อยู่กลางเป๊ะ
        icon: Icon(icon, color: color, size: size),
        onPressed: onTap,
      ),
    );
  }
}
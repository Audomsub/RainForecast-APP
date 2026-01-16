import 'package:flutter/material.dart';

class MapControlBar extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCurrentLocation;

  const MapControlBar({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCurrentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50, // ความกว้างของแท่งควบคุม
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5), // สีเทาดำโปร่งแสงแบบในรูป
        borderRadius: BorderRadius.circular(10), // ขอบมน
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ให้ความสูงพอดีกับเนื้อหา
        children: [
          // ปุ่มซูมเข้า (+)
          _buildIconButton(Icons.add, onZoomIn),
          
          const SizedBox(height: 8), // เว้นระยะห่าง
          
          // ปุ่มซูมออก (-)
          _buildIconButton(Icons.remove, onZoomOut),
          
          const SizedBox(height: 8), // เว้นระยะห่าง
          
          // ปุ่มตำแหน่งปัจจุบัน (Location)
          _buildIconButton(Icons.location_on, onCurrentLocation),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.transparent, // เพื่อให้กดได้ง่าย
        child: Icon(
          icon,
          color: Colors.white, // ไอคอนสีขาว
          size: 28,
        ),
      ),
    );
  }
}
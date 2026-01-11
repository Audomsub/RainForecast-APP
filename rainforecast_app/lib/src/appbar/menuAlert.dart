import 'package:flutter/material.dart';

class LeftButtons extends StatelessWidget {
  final VoidCallback onWeatherTap;
  final VoidCallback onNotificationTap;

  const LeftButtons({
    super.key,
    required this.onWeatherTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ปุ่มสภาพอากาศ (ก้อนเมฆ)
        _buildSideButton(
          icon: Icons.cloud,
          onTap: onWeatherTap,
        ),
        
        const SizedBox(height: 15), // ระยะห่าง
        
        // ปุ่มแจ้งเตือน (กระดิ่ง)
        _buildSideButtonWithBadge(
          icon: Icons.notifications,
          badgeCount: 1, // ตัวเลขแจ้งเตือน (Fix ไว้ก่อน)
          onTap: onNotificationTap,
        ),
      ],
    );
  }

  // Widget สร้างปุ่มธรรมดา
  Widget _buildSideButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6), // พื้นหลังสีดำโปร่งแสง
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  // Widget สร้างปุ่มพร้อมตัวเลขแจ้งเตือน (Badge)
  Widget _buildSideButtonWithBadge({
    required IconData icon,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            if (badgeCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
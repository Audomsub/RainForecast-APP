import 'package:flutter/material.dart';

class LegendPopup extends StatelessWidget {
  final VoidCallback onClose;

  const LegendPopup({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6), // พื้นหลังสีดำโปร่งแสง
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ส่วนหัวที่มีปุ่มปิด
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Rain Levels", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ],
          ),
          const Divider(color: Colors.white54),
          
          // รายการสีและความหมาย
          _buildLegendItem(Colors.greenAccent, "Light Rain"),
          _buildLegendItem(Colors.yellow, "Moderate Rain"),
          _buildLegendItem(Colors.orange, "Mod-Heavy Rain"),
          _buildLegendItem(Colors.red, "Heavy Rain"),
          _buildLegendItem(Colors.purple, "Very Heavy Rain"),
          _buildLegendItem(Colors.blue, "Extreme Rain"),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
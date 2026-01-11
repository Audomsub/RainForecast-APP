import 'package:flutter/material.dart';

class WeatherPopup extends StatelessWidget {
  final VoidCallback onClose;

  const WeatherPopup({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- กล่องข้อมูลหลัก (สีดำโปร่งแสง) ---
          Container(
            width: 300,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65), // พื้นหลังสีดำจางๆ
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // 1. ไอคอนก้อนเมฆใหญ่
                const Icon(
                  Icons.cloud_outlined, // หรือใช้ Icons.cloud
                  size: 100,
                  color: Colors.white,
                ),
                
                // ไอคอนหยดน้ำฝน (ตกแต่งเพิ่มให้เหมือนรูป)
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop, color: Colors.white, size: 30),
                      Icon(Icons.water_drop, color: Colors.white, size: 40),
                      Icon(Icons.water_drop, color: Colors.white, size: 30),
                    ],
                  ),
                ),

                // 2. ข้อความ Heavy Rain
                const Text(
                  "Heavy Rain",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // 3. แถบวันที่ (Date Selector)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. สถิติ (70% ฝน, 30% แดด)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _WeatherStat(icon: Icons.thunderstorm, label: "70 %"),
                    _WeatherStat(icon: Icons.wb_sunny, label: "30 %"),
                  ],
                ),

                const SizedBox(height: 20),

                // 5. แถบสีแสดงระดับ (Bar)
                Container(
                  height: 15,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE57373), // สีแดงอมส้มตามรูป
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- ปุ่มปิด (สีแดงกากบาท) ---
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                   BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                   )
                ]
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget ย่อยสำหรับแสดงค่า % (เพื่อลดโค้ดซ้ำ)
class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WeatherStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}
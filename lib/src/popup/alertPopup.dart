import 'package:flutter/material.dart';

class AlertPopup extends StatelessWidget {
  final VoidCallback onClose;

  const AlertPopup({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- กล่องข้อมูลหลัก ---
          Container(
            width: 300,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65), // พื้นหลังสีดำจาง
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // 1. หัวข้อ Warning
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Rain starting soon",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.warning_amber_rounded, color: Colors.yellow, size: 30),
                  ],
                ),
                
                // 2. ตัวเลขเวลาขนาดใหญ่ (10 min)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "10",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 90,
                        fontWeight: FontWeight.bold,
                        height: 1.0, // ลดระยะห่างบรรทัด
                      ),
                    ),
                    Text(
                      "min",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 3. ข้อมูลที่อยู่
                _buildInfoRow("address :", "ต.ช้างเผือก อ.เมือง จ.เชียงใหม่"),

                const SizedBox(height: 10),

                // 4. ระดับความรุนแรง (Level Bar)
                Row(
                  children: [
                    const SizedBox(
                      width: 70, 
                      child: Text("level :", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ),
                    Expanded(
                      child: Container(
                        height: 15,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE57373), // สีแดงอมส้ม
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 5. AI Prediction
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Prediction by AI : ",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      "70%",
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 24, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
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
                ],
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget จัดแถวข้อความ
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70, 
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15), // พื้นหลังจางๆ ให้ข้อความอ่านง่าย
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
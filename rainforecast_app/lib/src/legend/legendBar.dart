import 'package:flutter/material.dart';

class RainLegendBar extends StatelessWidget {
  const RainLegendBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30, // ความสูงของแถบ
      decoration: BoxDecoration(
        // ทำขอบมน
        borderRadius: BorderRadius.circular(15), 
        // ใส่เส้นขอบสีขาวจางๆ (ถ้าต้องการ)
        border: Border.all(color: Colors.white, width: 2),
        // สร้างการไล่สี (Gradient)
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.greenAccent, // เขียว (น้อย)
            Colors.yellow,      // เหลือง
            Colors.orange,      // ส้ม
            Colors.red,         // แดง
            Colors.purple,      // ม่วง
            Colors.blue,        // น้ำเงิน (มาก)
          ],
        ),
        // เพิ่มเงาให้ดูมีมิติ
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
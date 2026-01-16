import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/appbar/search.dart'; // import ไฟล์ search

class Bar1 extends StatelessWidget implements PreferredSizeWidget {
  const Bar1({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // เอา SearchBarWidget ที่แก้แล้วมาใส่ตรงนี้
      title: const SizedBox(
        height: 45, // กำหนดความสูงนิดนึงให้สวยงาม
        child: SearchBarWidget(), 
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0, 
    );
  }
}
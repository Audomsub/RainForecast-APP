import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/appbar/search.dart'; 

class Bar1 extends StatelessWidget implements PreferredSizeWidget {
  const Bar1({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: SizedBox(
        height: 45, 
        child: SearchBarWidget(
          onGoToLocation: (lat, lng) {
            
            debugPrint("ไปที่พิกัด: $lat, $lng");
          },
        ), 
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0, 
    );
  }
}
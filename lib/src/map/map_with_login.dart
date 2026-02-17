import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/map/mainmap.dart';

import '../login/login.dart';
import '../map/optionmap.dart';

class MapWithLogin extends StatelessWidget {
  const MapWithLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ///  แผนที่
          const MainMap(),

          ///  ฉากมืดโปร่งใส
          Container(color: Colors.black.withOpacity(0.25)),

          ///  Login Overlay
          const Center(child: AdminLoginOverlay()),
        ],
      ),
    );
  }
}

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
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5), 
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconButton(Icons.add, onZoomIn),
          const SizedBox(height: 8),
          _buildIconButton(Icons.remove, onZoomOut),
          const SizedBox(height: 8),
          _buildIconButton(Icons.location_on, onCurrentLocation),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // ทำให้กดติดง่ายขึ้นแม้โดนพื้นที่ว่าง
      child: Container(
        padding: const EdgeInsets.all(12), // เพิ่มพื้นที่ให้กดง่ายขึ้น
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatButton(Icons.add, onZoomIn),
        const SizedBox(height: 12),
        _buildFloatButton(Icons.remove, onZoomOut),
        const SizedBox(height: 12),
        _buildFloatButton(Icons.my_location_rounded, onCurrentLocation, isPrimary: true),
      ],
    );
  }

  Widget _buildFloatButton(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF6C63FF) : Colors.white, // ปุ่มหลักสีม่วง
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : const Color(0xFF2D3142),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class RainLegendBar extends StatelessWidget {
  const RainLegendBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ---------- Gradient Bar ----------
        Container(
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.greenAccent, // Light
                Colors.yellow,      // Moderate
                Colors.orange,      // Mod-Heavy
                Colors.red,         // Heavy
                Colors.purple,      // Very Heavy
                Colors.blue,        // Extreme
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),

        // ---------- Hover Areas ----------
        Positioned.fill(
          child: Row(
            children: const [
              _LegendHover(label: "Light Rain"),
              _LegendHover(label: "Moderate Rain"),
              _LegendHover(label: "Moderately Heavy Rain"),
              _LegendHover(label: "Heavy Rain"),
              _LegendHover(label: "Very Heavy Rain"),
              _LegendHover(label: "Extreme Rain"),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------- Hover Segment ----------
class _LegendHover extends StatelessWidget {
  final String label;

  const _LegendHover({required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 200),
        showDuration: const Duration(seconds: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            color: Colors.transparent, // พื้นที่ hover
          ),
        ),
      ),
    );
  }
}

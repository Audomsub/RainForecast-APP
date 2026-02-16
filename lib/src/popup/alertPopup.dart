import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class AlertPopup extends StatefulWidget {
  final VoidCallback onClose;
  final String address;
  final double intensity;
  final int probability;

  const AlertPopup({
    super.key,
    required this.onClose,
    this.address = "Unknown Location",
    this.intensity = 0.7,
    this.probability = 80,
  });

  @override
  State<AlertPopup> createState() => _AlertPopupState();
}

class _AlertPopupState extends State<AlertPopup> {

  @override
  void initState() {
    super.initState();
    _triggerVibration();
  }

  Future<void> _triggerVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 800);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.6),
                      Colors.black.withOpacity(0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      "คุณอยู่ในพื้นที่ฝนตก",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _infoRow(
                      icon: Icons.location_on_outlined,
                      value: widget.address,
                    ),

                    const SizedBox(height: 16),

                    _levelBar(widget.intensity),

                    const SizedBox(height: 20),

                    Text(
                      "ความน่าจะเป็น ${widget.probability}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: widget.onClose,
            child: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _levelBar(double value) {
    Color barColor;

    if (value < 0.3) {
      barColor = Colors.lightBlue;
    } else if (value < 0.7) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ระดับความแรงฝน",
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation(barColor),
        ),
      ],
    );
  }
}

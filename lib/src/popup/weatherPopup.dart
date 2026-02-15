import 'dart:ui';
import 'package:flutter/material.dart';

class WeatherPopup extends StatefulWidget {
  final String title;
  final String message;
  final Color color;
  final VoidCallback onClose;

  const WeatherPopup({
    super.key,
    required this.title,
    required this.message,
    required this.color,
    required this.onClose,
  });

  @override
  State<WeatherPopup> createState() => _WeatherPopupState();
}

class _WeatherPopupState extends State<WeatherPopup> {
  String selectedDate = "Today";

  final List<_DateOption> dates = const [
    _DateOption(
      value: "Today",
      title: "Today",
      subtitle: "Current weather",
      icon: Icons.today,
    ),
    _DateOption(
      value: "Tomorrow",
      title: "Tomorrow",
      subtitle: "Next day forecast",
      icon: Icons.calendar_today,
    ),
    _DateOption(
      value: "Next 3 Days",
      title: "Next 3 Days",
      subtitle: "Extended forecast",
      icon: Icons.date_range,
    ),
  ];

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
                padding: const EdgeInsets.symmetric(
                    vertical: 28, horizontal: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      size: 90,
                      color: widget.color,
                    ),

                    const SizedBox(height: 10),

                    // 🔥 ใช้ title จากภายนอก
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 🔥 ใช้ message จากภายนอก
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 18),

                    _dateDropdown(),

                    const SizedBox(height: 22),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: 0.7,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor:
                            AlwaysStoppedAnimation(widget.color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedDate,
          isExpanded: true,
          dropdownColor: Colors.black.withOpacity(0.9),
          icon: const Icon(Icons.expand_more, color: Colors.white),
          style: const TextStyle(color: Colors.white),
          items: dates.map((option) {
            return DropdownMenuItem<String>(
              value: option.value,
              child: Row(
                children: [
                  Icon(option.icon,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    option.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedDate = value!;
            });
          },
        ),
      ),
    );
  }
}

class _DateOption {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _DateOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

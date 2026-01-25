import 'dart:ui';
import 'package:flutter/material.dart';

class WeatherPopup extends StatefulWidget {
  final VoidCallback onClose;

  const WeatherPopup({super.key, required this.onClose});

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
          // ---------- Glass Card ----------
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    // ---------- Weather Icon ----------
                    const Icon(
                      Icons.cloud_outlined,
                      size: 90,
                      color: Colors.white,
                    ),

                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.water_drop,
                              size: 22, color: Colors.white70),
                          Icon(Icons.water_drop,
                              size: 30, color: Colors.white),
                          Icon(Icons.water_drop,
                              size: 22, color: Colors.white70),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ---------- Title ----------
                    const Text(
                      "Heavy Rain",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ---------- Dropdown ----------
                    _dateDropdown(),

                    const SizedBox(height: 22),

                    // ---------- Stats ----------
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _WeatherStat(
                            icon: Icons.thunderstorm, label: "70%"),
                        _WeatherStat(icon: Icons.wb_sunny, label: "30%"),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ---------- Level Bar ----------
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: 0.7,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFF6F61),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // ---------- Close Button ----------
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

  // ---------- Dropdown Widget ----------
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
                  Icon(option.icon, color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        option.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        option.subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

// ---------- Weather Stat ----------
class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WeatherStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------- Date Option Model ----------
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

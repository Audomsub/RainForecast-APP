import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SearchBarWidget extends StatefulWidget {
  final Function(double lat, double lng) onGoToLocation;

  const SearchBarWidget({
    super.key,
    required this.onGoToLocation,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    // --- 1. ตรวจสอบว่าเป็นพิกัด (Lat, Long) หรือไม่ ---
    // รูปแบบที่รองรับ: "13.75, 100.5" หรือ "13.75 100.5"
    final coordRegex = RegExp(r'^([-+]?\d*\.?\d+)[,\s]+([-+]?\d*\.?\d+)$');
    final match = coordRegex.firstMatch(query);

    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lon = double.tryParse(match.group(2)!);
      if (lat != null && lon != null) {
        widget.onGoToLocation(lat, lon);
        setState(() => _results = []);
        _controller.clear();
        FocusScope.of(context).unfocus();
        return;
      }
    }

    // --- 2. ถ้าไม่ใช่พิกัด ให้ค้นหาสถานที่ (จังหวัด/อำเภอ/หมู่บ้าน) ---
    setState(() => _loading = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$query'
        '&format=json'
        '&addressdetails=1' // ขอรายละเอียดที่อยู่
        '&limit=10'        // เพิ่มจำนวนผลลัพธ์
        '&countrycodes=th'  // เน้นในประเทศไทย
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'rainforecast_app'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _results = json.decode(response.body);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      debugPrint("Search Error: $e");
    }
  }

  void _selectPlace(dynamic place) {
    final lat = double.parse(place['lat']);
    final lon = double.parse(place['lon']);

    widget.onGoToLocation(lat, lon);

    setState(() {
      _results = [];
      _controller.clear();
    });

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา จังหวัด, อำเภอ หรือ พิกัด...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
            ],
          ),

          if (_loading)
            const LinearProgressIndicator(),

          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300), // จำกัดความสูง
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = _results[index];
                  final address = place['address'] ?? {};
                  
                  // สร้างคำอธิบายที่อยู่อ่านง่าย (ตำบล, อำเภอ, จังหวัด)
                  String subTitle = [
                    address['suburb'] ?? address['village'] ?? '',
                    address['district'] ?? address['city_district'] ?? '',
                    address['city'] ?? address['state'] ?? '',
                  ].where((s) => s.isNotEmpty).join(', ');

                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.redAccent),
                    title: Text(
                      place['display_name'].split(',')[0], // ชื่อสถานที่หลัก
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(subTitle.isNotEmpty ? subTitle : place['display_name']),
                    onTap: () => _selectPlace(place),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
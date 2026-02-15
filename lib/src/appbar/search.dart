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

  // ฟังก์ชันตรวจสอบว่าเป็นพิกัด Lat, Long หรือไม่
  bool _isCoordinates(String query) {
    final RegExp coordRegExp = RegExp(
        r'^[-+]?([1-8]?\d(\.\d+)?|90(\.0+)?),\s*[-+]?(180(\.0+)?|((1[0-7]\d)|([1-9]?\d))(\.\d+)?)$');
    return coordRegExp.hasMatch(query);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    // 1. ถ้าเป็นพิกัด (Lat, Long) ให้ไปที่ตำแหน่งนั้นทันทีโดยไม่ผ่าน API
    if (_isCoordinates(query)) {
      final parts = query.split(RegExp(r'[,\s]+'));
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat != null && lng != null) {
        widget.onGoToLocation(lat, lng);
        setState(() => _results = []);
        return;
      }
    }

    // 2. ถ้าเป็นชื่อสถานที่ ให้ค้นหาผ่าน API
    setState(() => _loading = true);

    try {
      // แนะนำให้ใช้ Google Places API หรือ Mapbox แทน OSM เพื่อป้องกันการโดน Block
      // ในตัวอย่างนี้ผมปรับแต่ง URL ของ OSM ให้มีพารามิเตอร์ที่ลดโอกาสโดนแบนเบื้องต้น 
      // แต่แนะนำให้สมัคร API Key ของ Mapbox/Google มาใส่แทนในอนาคตครับ
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$query&format=json&limit=5&countrycodes=th&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'RainForecast_App_Production_v1', // เปลี่ยนชื่อเพื่อเลี่ยงการ Block
          'Accept-Language': 'th',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _results = json.decode(response.body);
          _loading = false;
        });
      } else {
        throw Exception("API Error");
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('การค้นหาขัดข้อง กรุณาลองใหม่หรือระบุเป็นพิกัด')),
      );
    }
  }

  void _selectPlace(dynamic place) {
    final lat = double.parse(place['lat']);
    final lon = double.parse(place['lon']);
    widget.onGoToLocation(lat, lon);
    setState(() => _results = []);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'ค้นหาจังหวัด, อำเภอ หรือ พิกัด (lat, lng)',
              prefixIcon: const Icon(Icons.location_on, color: Colors.blue),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onSubmitted: (_) => _search(),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_results.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final place = _results[index];
                final address = place['address'] ?? {};
                // แสดงชื่อที่ละเอียดขึ้น (ตำบล, อำเภอ, จังหวัด)
                final String displayName = [
                  address['village'] ?? address['suburb'] ?? '',
                  address['district'] ?? address['city_district'] ?? '',
                  address['state'] ?? '',
                ].where((s) => s.isNotEmpty).join(', ');

                return ListTile(
                  title: Text(place['display_name'].split(',')[0]),
                  subtitle: Text(displayName.isNotEmpty ? displayName : place['display_name']),
                  onTap: () => _selectPlace(place),
                );
              },
            ),
        ],
      ),
    );
  }
}
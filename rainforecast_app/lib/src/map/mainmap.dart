import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http; 
import 'package:latlong2/latlong.dart';

class MainMap extends StatefulWidget {
  const MainMap({super.key, required this.searchText});

  final String searchText;

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
  final MapController _mapController = MapController();

  LatLng? _searchMarker;

  @override
  void didUpdateWidget(covariant MainMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchText.isNotEmpty &&
        widget.searchText != oldWidget.searchText) {
      _searchLocation(widget.searchText);
    }
  }

  Future<void> _searchLocation(String query) async {
  final url =
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}'
      '&format=json&limit=1';

  final response = await http.get(
    Uri.parse(url),
    headers: {
      'User-Agent': 'rainforecast-app', // ❗ จำเป็นมาก
    },
  );

  if (response.statusCode == 200) {
    final List data = json.decode(response.body);

    if (data.isNotEmpty) {
      final lat = double.parse(data[0]['lat']);
      final lon = double.parse(data[0]['lon']);
      final position = LatLng(lat, lon);

      if (!mounted) return;

      setState(() {
        _searchMarker = position; // 📍 ปัก marker
      });

      _mapController.move(position, 14);
    }
  }
}
@override
Widget build(BuildContext context) {
  return FlutterMap(
    mapController: _mapController,
    options: const MapOptions(
      initialCenter: LatLng(13.7563, 100.5018), // Bangkok
      initialZoom: 9.2,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.rainforecast_app',
      ),

      // 📍 Marker ที่ตำแหน่งค้นหา
      if (_searchMarker != null)
        MarkerLayer(
          markers: [
            Marker(
              point: _searchMarker!,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_pin,
                color: Colors.red,
                size: 40,
              ),
            ),
          ],
        ),
    ],
  );
}
}
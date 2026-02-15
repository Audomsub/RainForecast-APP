import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math'; 
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:image/image.dart' as img; 
import '../service/db_service.dart';
import 'optionmap.dart'; 

class MainMap extends StatefulWidget {
  const MainMap({super.key, required this.searchText});
  final String searchText;

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
  final MapController _mapController = MapController();
  final DBService _dbService = DBService();
  
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _rainReports = [];
  late final RealtimeChannel _rainChannel; 
  
  Uint8List? _processedRadarBytes; 
  Timer? _radarTimer;
  
  // พิกัดสถานีเรดาร์
  final LatLng _radarCenter = const LatLng(18.163, 100.354);
  late LatLngBounds _radarBounds;

  @override
  void initState() {
    super.initState();
    _calculateRadarBounds();
    _fetchLatestRadar();     
    
    // อัปเดตเรดาร์ทุก 6 นาที
    _radarTimer = Timer.periodic(const Duration(minutes: 6), (timer) {
      _fetchLatestRadar();
    });

    _fetchReports();
    _handleCurrentLocation(); 
    _subscribeToRainReports();
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    Supabase.instance.client.removeChannel(_rainChannel);
    super.dispose();
  }

  // --- ฟังก์ชันควบคุมแผนที่ ---
  void _handleZoomIn() {
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _handleZoomOut() {
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  Future<void> _handleCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng userLatLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _currentLocation = userLatLng);
        _mapController.move(userLatLng, 15);
      }
    } catch (e) {
      debugPrint("Error location: $e");
    }
  }

  // --- ฟังก์ชันจัดการข้อมูล Radar ---
  void _calculateRadarBounds() {
    const double radiusKm = 240.0;
    const double kmPerLatDegree = 111.0;
    
    // ✅ ขยับภาพเรดาร์ขึ้นด้านบน (Latitude Offset)
    const double latOffset = 0.125; 

    // ✅ ขยับภาพเรดาร์ไปทางซ้าย (Longitude Offset)
    // การลบค่า Longitude จะทำให้ภาพเลื่อนไปทางทิศตะวันตก (ซ้าย)
    const double lngOffset = 0.08; 

    double deltaLat = radiusKm / kmPerLatDegree;
    double kmPerLngDegree = 111.0 * cos(_radarCenter.latitude * pi / 180);
    double deltaLng = radiusKm / kmPerLngDegree;

    _radarBounds = LatLngBounds(
      LatLng(
        (_radarCenter.latitude - deltaLat) + latOffset, 
        (_radarCenter.longitude - deltaLng) - lngOffset
      ),
      LatLng(
        (_radarCenter.latitude + deltaLat) + latOffset, 
        (_radarCenter.longitude + deltaLng) - lngOffset
      ),
    );
  }

  Future<void> _fetchLatestRadar() async {
    const String baseUrl = "http://10.0.2.2:3000"; 
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/radar/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          String path = data['data']['filepath'];
          final imageResponse = await http.get(Uri.parse('$baseUrl$path'));
          if (imageResponse.statusCode == 200) {
            final processed = await _processRadarImage(imageResponse.bodyBytes);
            if (mounted) {
              setState(() => _processedRadarBytes = processed);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error radar fetch: $e");
    }
  }

  Future<Uint8List?> _processRadarImage(Uint8List bytes) async {
    img.Image? original = img.decodeImage(bytes);
    if (original == null) return null;

    // ตัดภาพด้านขวาออกให้เหลือ 800x800
    img.Image cropped = img.copyCrop(original, x: 0, y: 0, width: 800, height: 800);
    img.Image masked = img.Image(width: 800, height: 800, numChannels: 4);

    for (var y = 0; y < cropped.height; y++) {
      for (var x = 0; x < cropped.width; x++) {
        final pixel = cropped.getPixel(x, y);
        
        // กรองเฉพาะพิกเซลสีฝน (ไม่ใช่พื้นหลังสีดำหรือเทา)
        if (_isRainPixel(pixel)) {
          masked.setPixel(x, y, pixel);
        } else {
          // ทำให้โปร่งใส 100%
          masked.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    return Uint8List.fromList(img.encodePng(masked));
  }

  bool _isRainPixel(img.Pixel pixel) {
    if (pixel.luminance < 0.1) return false;
    num diff = (pixel.r - pixel.g).abs() + (pixel.g - pixel.b).abs();
    if (diff < 25) return false;
    return (pixel.r > 25 || pixel.g > 25);
  }

  // --- ระบบรายงานฝน ---
  void _subscribeToRainReports() {
    _rainChannel = Supabase.instance.client
      .channel('public:rain_reports')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'rain_reports',
        callback: (payload) => _fetchReports(),
      )
      .subscribe();
  }

  Future<void> _fetchReports() async {
    List<Map<String, dynamic>> reports = await _dbService.getSupabaseReports();
    if (reports.isEmpty) reports = await _dbService.getLocalReports();
    if (mounted) setState(() => _rainReports = reports);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(13.7563, 100.5018),
            initialZoom: 6.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.example.rainforecast_app',
            ),
            
            if (_processedRadarBytes != null)
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    bounds: _radarBounds,
                    opacity: 0.85,
                    imageProvider: MemoryImage(_processedRadarBytes!),
                  ),
                ],
              ),

            MarkerLayer(
              markers: _rainReports.map((report) {
                return Marker(
                  point: LatLng(report['latitude'], report['longitude']),
                  width: 40, height: 40,
                  child: Icon(Icons.cloud, color: Color(report['color_value'])),
                );
              }).toList(),
            ),

            if (_currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation!,
                    width: 60, height: 60,
                    child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 30),
                  ),
                ],
              ),
          ],
        ),
        
        Positioned(
          right: 16, 
          bottom: 120, 
          child: MapControlBar(
            onZoomIn: _handleZoomIn,
            onZoomOut: _handleZoomOut,
            onCurrentLocation: _handleCurrentLocation,
          ),
        ),
      ],
    );
  }
}
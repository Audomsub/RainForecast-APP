import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
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
  
  LatLng? _searchMarker;
  LatLng? _currentLocation;
  
  List<Map<String, dynamic>> _rainReports = [];

  late final RealtimeChannel _rainChannel; 

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _handleCurrentLocation();
    
    _subscribeToRainReports();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_rainChannel);
    super.dispose();
  }

  void _subscribeToRainReports() {
    _rainChannel = Supabase.instance.client
      .channel('public:rain_reports')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'rain_reports',
        callback: (payload) {
          print('⚡ Realtime Update: มีจุดฝนตกใหม่!');
          _fetchReports();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚡ มีรายงานฝนตกจุดใหม่!')),
            );
          }
        },
      )
      .subscribe();
  }

  Future<void> _fetchReports() async {
    List<Map<String, dynamic>> reports = await _dbService.getSupabaseReports();
    
    if (reports.isEmpty) {
      print("⚠️ ใช้ข้อมูล Offline Mode");
      reports = await _dbService.getLocalReports();
    } else {
      print("☁️ ใช้ข้อมูล Online Mode (${reports.length} จุด)");
    }

    if (mounted) {
      setState(() => _rainReports = reports);
    }
  }

  void _showReportDetail(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report['image_path'] != null && File(report['image_path']).existsSync())
                Container(
                  height: 200,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    image: DecorationImage(
                      image: FileImage(File(report['image_path'])),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              Row(
                children: [
                  Icon(IconData(report['icon_code'], fontFamily: 'MaterialIcons'), 
                     color: Color(report['color_value']), size: 40),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report['cat_name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('โดย: ${report['reporter_name']}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 30),
              Text('รายละเอียด: ${report['description'] ?? "-"}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Text('เวลา: ${report['timestamp'].substring(11, 16)} น.', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

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
      
      try {
        Position position = await Geolocator.getCurrentPosition();
        LatLng userLatLng = LatLng(position.latitude, position.longitude);
        setState(() => _currentLocation = userLatLng);
        _mapController.move(userLatLng, 15);
      } catch (e) {
        debugPrint("Error: $e");
      }
  }

  @override
  void didUpdateWidget(covariant MainMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchText.isNotEmpty && widget.searchText != oldWidget.searchText) {
      _searchLocation(widget.searchText);
    }
  }

  Future<void> _searchLocation(String query) async {
    final url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1';
    try {
        final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'rainforecast-app'});
        if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
            final lat = double.parse(data[0]['lat']);
            final lon = double.parse(data[0]['lon']);
            final position = LatLng(lat, lon);
            if (!mounted) return;
            setState(() => _searchMarker = position);
            _mapController.move(position, 14);
        }
        }
    } catch (e) {
        debugPrint("Error searching location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(13.7563, 100.5018),
            initialZoom: 9.2,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.rainforecast_app',
            ),
            
            // แสดงเฉพาะหมุดรายงานฝนตกที่มีอยู่แล้ว
            MarkerLayer(
              markers: _rainReports.map((report) {
                return Marker(
                  point: LatLng(report['latitude'], report['longitude']),
                  width: 50,
                  height: 50,
                  child: GestureDetector(
                    onTap: () => _showReportDetail(report),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Color(report['color_value']), width: 3),
                            boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
                          ),
                        ),
                        Icon(
                          IconData(report['icon_code'], fontFamily: 'MaterialIcons'),
                          color: Color(report['color_value']),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
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
              
             if (_searchMarker != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _searchMarker!,
                    width: 40, height: 40,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ),
                ],
              ),
          ],
        ),
        
        Positioned(
          right: 16, 
          bottom: 120, // ✅ แก้ไข: ขยับขึ้นจาก 40 เป็น 120 เพื่อให้พ้นแถบด้านล่าง
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
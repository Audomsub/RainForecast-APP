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
import 'package:image/image.dart' as img; // สำหรับประมวลผลรูปภาพ
import '../service/db_service.dart';
import 'optionmap.dart';
import '../popup/alertPopup.dart'; // ✅ Import AlertPopup

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
  img.Image? _radarImageForLogic; // ✅ เก็บรูปภาพสำหรับตรวจสอบ Pixel ฝน
  Timer? _radarTimer;

  // ✅ ตัวแปรสำหรับระบบแจ้งเตือน
  bool _isAlertShowing = false;
  DateTime? _lastAlertTime; // เก็บเวลาแจ้งเตือนล่าสุด เพื่อทำ Cooldown

  // พิกัดสถานีเรดาร์ (ศูนย์กลาง)
  final LatLng _radarCenter = const LatLng(18.163, 100.354);
  late LatLngBounds _radarBounds;

  @override
  void initState() {
    super.initState();
    _calculateRadarBounds();
    _fetchLatestRadar();

    // ตั้งค่าอัปเดตเรดาร์ทุก 6 นาที
    _radarTimer = Timer.periodic(const Duration(minutes: 6), (timer) {
      _fetchLatestRadar();
    });

    _fetchReports();
    _subscribeToRainReports();
    
    // ✅ เรียกฟังก์ชันเช็ค Permission ก่อนเริ่มติดตามตำแหน่ง
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    Supabase.instance.client.removeChannel(_rainChannel);
    super.dispose();
  }

  // --- 🔒 ฟังก์ชันขออนุญาตเข้าถึงตำแหน่ง (เพิ่มใหม่) ---
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. เช็คว่าเปิด GPS หรือยัง
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    // 2. เช็ค Permission ปัจจุบัน
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 3. ถ้ายังไม่มี ให้ขอ Permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return;
    } 

    // ✅ ถ้าผ่านหมดแล้ว ให้เริ่มดึงตำแหน่งและติดตามตำแหน่งได้เลย
    _handleCurrentLocation();
    _startLocationStream();
  }

  // --- 🔔 ฟังก์ชันตรวจสอบฝนและแจ้งเตือน ---
  void _startLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, 
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      LatLng newLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = newLoc;
        });
        // ทุกครั้งที่ตำแหน่งเปลี่ยน ให้เช็คว่าอยู่ในฝนไหม
        _checkUserLocationInRain(newLoc);
      }
    }, onError: (e) {
        debugPrint("Location Stream Error: $e");
    });
  }

  void _checkUserLocationInRain(LatLng userLocation) {
    if (_radarImageForLogic == null || _isAlertShowing) return;

    // เช็ค Cooldown: ถ้าเพิ่งแจ้งเตือนไปไม่ถึง 5 นาที ไม่ต้องแจ้งซ้ำ
    if (_lastAlertTime != null && DateTime.now().difference(_lastAlertTime!).inMinutes < 5) {
      return;
    }

    // 1. ตรวจสอบว่าอยู่ในขอบเขตภาพ Radar หรือไม่
    if (!_radarBounds.contains(userLocation)) return;

    // 2. คำนวณพิกัด Pixel (Mapping LatLng -> Pixel X,Y)
    double latRange = _radarBounds.north - _radarBounds.south;
    double lngRange = _radarBounds.east - _radarBounds.west;

    // คำนวณ Ratio (0.0 - 1.0)
    double xRatio = (userLocation.longitude - _radarBounds.west) / lngRange;
    // แกน Y: บนลงล่าง (North -> South) *ในรูปภาพ Y=0 คือด้านบน
    double yRatio = (_radarBounds.north - userLocation.latitude) / latRange;

    int pixelX = (xRatio * _radarImageForLogic!.width).round();
    int pixelY = (yRatio * _radarImageForLogic!.height).round();

    // ป้องกัน Index Out of Bounds
    if (pixelX < 0 || pixelX >= _radarImageForLogic!.width || 
        pixelY < 0 || pixelY >= _radarImageForLogic!.height) return;

    // 3. อ่านค่าสีของ Pixel นั้น
    img.Pixel pixel = _radarImageForLogic!.getPixel(pixelX, pixelY);

    // 4. ตรวจสอบว่าเป็นฝนหรือไม่ (ใช้ Logic เดียวกับ _isRainPixel)
    if (_isRainPixel(pixel)) {
       // ประเมินความแรงฝนคร่าวๆ จากสี
       double intensity = 0.5; // ค่า Default (ปานกลาง)
       String rainLevel = "Moderate Rain";

       if (pixel.r > 200 && pixel.g < 100) {
         intensity = 0.9; // แดง = หนัก
         rainLevel = "Heavy Rain";
       } else if (pixel.g > 200 && pixel.r < 150) {
         intensity = 0.3; // เขียว = เบา
         rainLevel = "Light Rain";
       }

       _triggerRainAlert(intensity, rainLevel);
    }
  }

  void _triggerRainAlert(double intensity, String rainLevel) {
    setState(() {
      _isAlertShowing = true;
      _lastAlertTime = DateTime.now();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertPopup(
          onClose: () {
            Navigator.of(context).pop();
            if (mounted) {
                setState(() => _isAlertShowing = false);
            }
          },
          address: "ตำแหน่งปัจจุบันของคุณ", 
          intensity: intensity,
          probability: (intensity * 100).toInt(),
        );
      },
    );
  }
  // --------------------------------------------------

  // --- ฟังก์ชันจัดการข้อมูล Radar ---
  void _calculateRadarBounds() {
    const double radiusKm = 240.0;
    const double kmPerLatDegree = 111.0;

    // ค่า Offset สำหรับจูนตำแหน่งภาพให้ตรงแผนที่จริง
    const double latOffset = 0.15;
    const double lngOffset = 0.070;

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
    // ⚠️ หมายเหตุ: 10.0.2.2 ใช้สำหรับ Android Emulator
    const String baseUrl = "https://rainforecast-app.onrender.com";
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/radar/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          String path = data['data']['filepath'];
          final imageResponse = await http.get(Uri.parse('$baseUrl$path'));
          if (imageResponse.statusCode == 200) {
            
            // เรียกประมวลผลภาพ
            final processed = await _processRadarImage(imageResponse.bodyBytes);
            
            if (mounted && processed != null) {
              setState(() {
                _processedRadarBytes = processed;
                _radarImageForLogic = img.decodeImage(processed); 
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error radar fetch: $e");
    }
  }

  // ✅✅✅ ฟังก์ชันประมวลผลหลัก: ตัดวงกลม + กรองสีพื้นหลังออก ✅✅✅
  Future<Uint8List?> _processRadarImage(Uint8List bytes) async {
    img.Image? original = img.decodeImage(bytes);
    if (original == null) return null;

    img.Image cropped = img.copyCrop(original, x: 0, y: 0, width: 800, height: 800);
    img.Image masked = img.Image(width: 800, height: 800, numChannels: 4);

    final centerX = cropped.width / 2;
    final centerY = cropped.height / 2;
    final radiusSquared = pow((cropped.width / 2) - 5, 2);

    for (var y = 0; y < cropped.height; y++) {
      for (var x = 0; x < cropped.width; x++) {
        final dx = x - centerX;
        final dy = y - centerY;
        
        if (dx * dx + dy * dy > radiusSquared) {
           masked.setPixelRgba(x, y, 0, 0, 0, 0); 
           continue;
        }

        final pixel = cropped.getPixel(x, y);

        if (_isRainPixel(pixel)) {
          masked.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 210);
        } else {
          masked.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    return Uint8List.fromList(img.encodePng(masked));
  }

  // ✅✅✅ Logic ใหม่: ฆ่าสีป่าและภูเขาให้เรียบ ✅✅✅
  bool _isRainPixel(img.Pixel pixel) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    // เพิ่ม: ถ้าเป็นสีโปร่งใส (Alpha=0) ให้ถือว่าไม่ใช่ฝนทันที
    if (pixel.a == 0) return false;

    final maxVal = max(r, max(g, b));
    final minVal = min(r, min(g, b));
    if ((maxVal - minVal) < 60) return false; 

    // Mountain Killer
    if (r > g) {
      if (g > 80) return false; 
    }

    // Forest Killer
    if (g > r) {
      if ((g - r) < 70) return false;
      if (g < 130) return false;
    }

    // Whitelist
    bool isGreenRain = (g > 140) && (g > r + 70) && (g > b + 70);
    bool isYellowRain = (r > 150 && g > 150 && b < 80);
    bool isRedRain = (r > 150 && g < 80 && b < 80);

    return isGreenRain || isYellowRain || isRedRain;
  }

  // --- ส่วนฟังก์ชันควบคุมแผนที่ (Zoom / GPS / Reports) ---
  void _handleZoomIn() {
    double currentZoom = _mapController.camera.zoom;
    if (currentZoom + 1 <= 15.0) {
      _mapController.move(_mapController.camera.center, currentZoom + 1);
    } else {
       _mapController.move(_mapController.camera.center, 15.0);
    }
  }

  void _handleZoomOut() {
    double currentZoom = _mapController.camera.zoom;
    if (currentZoom - 1 >= 4.0) {
      _mapController.move(_mapController.camera.center, currentZoom - 1);
    } else {
       _mapController.move(_mapController.camera.center, 4.0);
    }
  }

  Future<void> _handleCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng userLatLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _currentLocation = userLatLng);
        _mapController.move(userLatLng, 8.0);
        _checkUserLocationInRain(userLatLng);
      }
    } catch (e) {
      debugPrint("Error location: $e");
    }
  }

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
            minZoom: 4.0,  
            maxZoom: 15.0, 
          ),
          children: [
            // ✅ 1. OpenStreetMap Layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.rainforecast_app',
            ),

            // ✅ ชั้นแสดงผล Radar
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

            // ชั้นแสดง Markers รายงานฝน
            MarkerLayer(
              markers: _rainReports.map((report) {
                return Marker(
                  point: LatLng(report['latitude'], report['longitude']),
                  width: 40, height: 40,
                  child: Icon(Icons.cloud, color: Color(report['color_value'])),
                );
              }).toList(),
            ),

            // ชั้นแสดงจุดตำแหน่งปัจจุบัน
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

            // ✅ 2. Attribution
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                ),
              ],
            ),
          ],
        ),

        // ปุ่มควบคุม Zoom และ ตำแหน่ง
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
// // c:\Users\User\Desktop\RainForecast-APP\lib\src\map\mainmap.dart

// import 'dart:io';
// import 'dart:convert';
// import 'dart:async';
// import 'dart:math';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:latlong2/latlong.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:image/image.dart' as img; // สำหรับประมวลผลรูปภาพ
// import '../service/db_service.dart';
// import 'optionmap.dart';

// class MainMap extends StatefulWidget {
//   const MainMap({super.key, required this.searchText});
//   final String searchText;

//   @override
//   State<MainMap> createState() => _MainMapState();
// }

// class _MainMapState extends State<MainMap> {
//   final MapController _mapController = MapController();
//   final DBService _dbService = DBService();

//   LatLng? _currentLocation;
//   List<Map<String, dynamic>> _rainReports = [];
//   late final RealtimeChannel _rainChannel;

//   Uint8List? _processedRadarBytes;
//   Timer? _radarTimer;

//   // พิกัดสถานีเรดาร์ (ศูนย์กลาง)
//   final LatLng _radarCenter = const LatLng(18.163, 100.354);
//   late LatLngBounds _radarBounds;

//   @override
//   void initState() {
//     super.initState();
//     _calculateRadarBounds();
//     _fetchLatestRadar();

//     // ตั้งค่าอัปเดตเรดาร์ทุก 6 นาที
//     _radarTimer = Timer.periodic(const Duration(minutes: 6), (timer) {
//       _fetchLatestRadar();
//     });

//     _fetchReports();
//     _handleCurrentLocation();
//     _subscribeToRainReports();
//   }

//   @override
//   void dispose() {
//     _radarTimer?.cancel();
//     Supabase.instance.client.removeChannel(_rainChannel);
//     super.dispose();
//   }

//   // --- ฟังก์ชันจัดการข้อมูล Radar ---
//   void _calculateRadarBounds() {
//     const double radiusKm = 240.0;
//     const double kmPerLatDegree = 111.0;

//     // ค่า Offset สำหรับจูนตำแหน่งภาพให้ตรงแผนที่จริง
//     const double latOffset = 0.15;
//     const double lngOffset = 0.070;

//     double deltaLat = radiusKm / kmPerLatDegree;
//     double kmPerLngDegree = 111.0 * cos(_radarCenter.latitude * pi / 180);
//     double deltaLng = radiusKm / kmPerLngDegree;

//     _radarBounds = LatLngBounds(
//       LatLng(
//         (_radarCenter.latitude - deltaLat) + latOffset,
//         (_radarCenter.longitude - deltaLng) - lngOffset
//       ),
//       LatLng(
//         (_radarCenter.latitude + deltaLat) + latOffset,
//         (_radarCenter.longitude + deltaLng) - lngOffset
//       ),
//     );
//   }

//   Future<void> _fetchLatestRadar() async {
//     // ⚠️ หมายเหตุ: 10.0.2.2 ใช้สำหรับ Android Emulator
//     // หากรันบนเครื่องจริงต้องเปลี่ยนเป็น IP ของเครื่อง Server (เช่น 192.168.x.x)
//     const String baseUrl = "http://10.0.2.2:3000";
//     try {
//       final response = await http.get(Uri.parse('$baseUrl/api/radar/latest'));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['success'] == true && data['data'] != null) {
//           String path = data['data']['filepath'];
//           final imageResponse = await http.get(Uri.parse('$baseUrl$path'));
//           if (imageResponse.statusCode == 200) {
//             // ส่งไปประมวลผลตัดขอบและกรองสี
//             final processed = await _processRadarImage(imageResponse.bodyBytes);
//             if (mounted) {
//               setState(() => _processedRadarBytes = processed);
//             }
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint("❌ Error radar fetch: $e");
//     }
//   }

//   // ✅✅✅ ฟังก์ชันประมวลผลหลัก: ตัดวงกลม + กรองสีพื้นหลังออก ✅✅✅
//   Future<Uint8List?> _processRadarImage(Uint8List bytes) async {
//     img.Image? original = img.decodeImage(bytes);
//     if (original == null) return null;

//     // 1. ตัดภาพ (Crop) ให้เหลือขนาด 800x800
//     img.Image cropped = img.copyCrop(original, x: 0, y: 0, width: 800, height: 800);
//     img.Image masked = img.Image(width: 800, height: 800, numChannels: 4);

//     // จุดศูนย์กลางและรัศมี (ลบ 5px เพื่อตัดขอบดำทิ้ง)
//     final centerX = cropped.width / 2;
//     final centerY = cropped.height / 2;
//     final radiusSquared = pow((cropped.width / 2) - 5, 2);

//     for (var y = 0; y < cropped.height; y++) {
//       for (var x = 0; x < cropped.width; x++) {
//         // 2. ตัดวงกลม: คำนวณระยะห่าง
//         final dx = x - centerX;
//         final dy = y - centerY;
        
//         // ถ้าอยู่นอกวงกลม ให้ข้ามไปเลย (เป็นสีใส)
//         if (dx * dx + dy * dy > radiusSquared) {
//            masked.setPixelRgba(x, y, 0, 0, 0, 0); 
//            continue;
//         }

//         final pixel = cropped.getPixel(x, y);

//         // 3. ตรวจสอบสีด้วย Logic ใหม่ (Strict Mode)
//         if (_isRainPixel(pixel)) {
//           // ถ้าเป็นฝน ให้แสดงผล (ปรับ Alpha = 210 เพื่อความสวยงาม)
//           masked.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 210);
//         } else {
//           // ไม่ใช่ฝน (เป็นป่า/ภูเขา/พื้นหลัง) -> ให้เป็นสีใส
//           masked.setPixelRgba(x, y, 0, 0, 0, 0);
//         }
//       }
//     }
//     return Uint8List.fromList(img.encodePng(masked));
//   }

//   // ✅✅✅ Logic ใหม่ (โหดกว่าเดิม): ฆ่าสีป่าและภูเขาให้เรียบ ✅✅✅
//   bool _isRainPixel(img.Pixel pixel) {
//     final r = pixel.r.toInt();
//     final g = pixel.g.toInt();
//     final b = pixel.b.toInt();

//     // 1. กรองสีตุ่นๆ (Desaturated Colors)
//     // ฝน Neon สีจะสดมาก ค่า Max กับ Min ต้องต่างกันเยอะๆ
//     // ถ้าต่างกันน้อย แปลว่าเป็นสีเทาๆ หรือสีตุ่นๆ ของแผนที่
//     final maxVal = max(r, max(g, b));
//     final minVal = min(r, min(g, b));
//     if ((maxVal - minVal) < 60) return false; // เพิ่มเกณฑ์จาก 30 เป็น 60

//     // 2. ฆ่า "ภูเขา" (Mountain Killer)
//     // ภูเขาคือสีส้ม/น้ำตาล (Red > Green) โดยที่ Green มีค่าปานกลาง (เช่น R=200, G=150 -> ส้ม)
//     // ฝนแดง (Heavy Rain) คือ (R=200, G=0 -> แดงสด)
//     if (r > g) {
//       // ถ้าแดงนำ แต่เขียวเกิน 80 แสดงว่าเป็นส้ม/น้ำตาล (ภูเขา) -> ไม่ใช่ฝน!
//       if (g > 80) return false; 
//     }

//     // 3. ฆ่า "ป่า" (Forest Killer)
//     // ป่าคือสีเขียวขี้ม้า (Green > Red) แต่ต่างกันไม่มาก (เช่น G=150, R=120)
//     // ฝนเขียว (Neon) คือต่างกันเยอะมาก (เช่น G=200, R=20)
//     if (g > r) {
//       // ถ้าเขียวชนะแดงไม่ถึง 70 แต้ม แสดงว่าเป็นป่า -> ไม่ใช่ฝน!
//       if ((g - r) < 70) return false;
//       // ถ้าเขียวมืดเกินไป (ต่ำกว่า 130) -> ไม่ใช่ฝน!
//       if (g < 130) return false;
//     }

//     // 4. Whitelist: ถ้าผ่านด่านมรณะข้างบนมาได้ เช็คว่าเป็นสีฝนไหม
    
//     // 🟢 ฝนสีเขียว (Neon Green Only)
//     bool isGreenRain = (g > 140) && (g > r + 70) && (g > b + 70);
    
//     // 🟡 ฝนสีเหลือง (Bright Yellow Only)
//     // สีเหลืองคือ R และ G สูงทั้งคู่ แต่น้ำเงินต้องต่ำติดดิน
//     bool isYellowRain = (r > 150 && g > 150 && b < 80);

//     // 🔴 ฝนสีแดง (Deep Red Only)
//     // แดงสูง เขียวต่ำ น้ำเงินต่ำ
//     bool isRedRain = (r > 150 && g < 80 && b < 80);

//     return isGreenRain || isYellowRain || isRedRain;
//   }

//   // --- ส่วนฟังก์ชันควบคุมแผนที่ (Zoom / GPS / Reports) ---
//   void _handleZoomIn() {
//     double currentZoom = _mapController.camera.zoom;
//     _mapController.move(_mapController.camera.center, currentZoom + 1);
//   }

//   void _handleZoomOut() {
//     double currentZoom = _mapController.camera.zoom;
//     _mapController.move(_mapController.camera.center, currentZoom - 1);
//   }

//   Future<void> _handleCurrentLocation() async {
//     try {
//       Position position = await Geolocator.getCurrentPosition();
//       LatLng userLatLng = LatLng(position.latitude, position.longitude);
//       if (mounted) {
//         setState(() => _currentLocation = userLatLng);
//         _mapController.move(userLatLng, 15);
//       }
//     } catch (e) {
//       debugPrint("Error location: $e");
//     }
//   }

//   void _subscribeToRainReports() {
//     _rainChannel = Supabase.instance.client
//       .channel('public:rain_reports')
//       .onPostgresChanges(
//         event: PostgresChangeEvent.insert,
//         schema: 'public',
//         table: 'rain_reports',
//         callback: (payload) => _fetchReports(),
//       )
//       .subscribe();
//   }

//   Future<void> _fetchReports() async {
//     List<Map<String, dynamic>> reports = await _dbService.getSupabaseReports();
//     if (reports.isEmpty) reports = await _dbService.getLocalReports();
//     if (mounted) setState(() => _rainReports = reports);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         FlutterMap(
//           mapController: _mapController,
//           options: const MapOptions(
//             initialCenter: LatLng(13.7563, 100.5018),
//             initialZoom: 6.0,
//           ),
//           children: [
//             // ชั้นแผนที่พื้นหลัง (Google Maps)
//             TileLayer(
//               urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
//               userAgentPackageName: 'com.example.rainforecast_app',
//             ),

//             // ✅ ชั้นแสดงผล Radar (แสดงเฉพาะวงกลมและเฉพาะสีฝน)
//             if (_processedRadarBytes != null)
//               OverlayImageLayer(
//                 overlayImages: [
//                   OverlayImage(
//                     bounds: _radarBounds,
//                     opacity: 0.85, 
//                     imageProvider: MemoryImage(_processedRadarBytes!),
//                   ),
//                 ],
//               ),

//             // ชั้นแสดง Markers รายงานฝน
//             MarkerLayer(
//               markers: _rainReports.map((report) {
//                 return Marker(
//                   point: LatLng(report['latitude'], report['longitude']),
//                   width: 40, height: 40,
//                   child: Icon(Icons.cloud, color: Color(report['color_value'])),
//                 );
//               }).toList(),
//             ),

//             // ชั้นแสดงจุดตำแหน่งปัจจุบัน
//             if (_currentLocation != null)
//               MarkerLayer(
//                 markers: [
//                   Marker(
//                     point: _currentLocation!,
//                     width: 60, height: 60,
//                     child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 30),
//                   ),
//                 ],
//               ),
//           ],
//         ),

//         // ปุ่มควบคุม Zoom และ ตำแหน่ง
//         Positioned(
//           right: 16,
//           bottom: 120,
//           child: MapControlBar(
//             onZoomIn: _handleZoomIn,
//             onZoomOut: _handleZoomOut,
//             onCurrentLocation: _handleCurrentLocation,
//           ),
//         ),
//       ],
//     );
//   }
// }



// c:\Users\User\Desktop\RainForecast-APP\lib\src\map\mainmap.dart

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ต้องมีอันนี้เพื่อโหลดรูปจาก Assets
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

  // 🔧🔧🔧 โหมดทดสอบ (Test Mode) 🔧🔧🔧
  // เปลี่ยนเป็น true = ใช้รูปจาก assets/test_radar.png เพื่อทดสอบ
  // เปลี่ยนเป็น false = ใช้รูปจริงจาก Server API
  final bool _isTestMode = true; 

  // พิกัดสถานีเรดาร์ (ศูนย์กลาง)
  final LatLng _radarCenter = const LatLng(18.163, 100.354);
  late LatLngBounds _radarBounds;

  @override
  void initState() {
    super.initState();
    _calculateRadarBounds();
    _fetchLatestRadar(); // เรียกฟังก์ชันดึงข้อมูล (จะเช็ค Test Mode ข้างใน)

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

  void _calculateRadarBounds() {
    const double radiusKm = 240.0;
    const double kmPerLatDegree = 111.0;
    const double latOffset = 0.15;
    const double lngOffset = 0.070;

    double deltaLat = radiusKm / kmPerLatDegree;
    double kmPerLngDegree = 111.0 * cos(_radarCenter.latitude * pi / 180);
    double deltaLng = radiusKm / kmPerLngDegree;

    _radarBounds = LatLngBounds(
      LatLng((_radarCenter.latitude - deltaLat) + latOffset, (_radarCenter.longitude - deltaLng) - lngOffset),
      LatLng((_radarCenter.latitude + deltaLat) + latOffset, (_radarCenter.longitude + deltaLng) - lngOffset),
    );
  }

  // ✅ ฟังก์ชันดึงข้อมูล (รองรับ Test Mode)
  Future<void> _fetchLatestRadar() async {
    // กรณีโหมดทดสอบ: โหลดรูปจากเครื่อง
    if (_isTestMode) {
      try {
        final ByteData data = await rootBundle.load('assets/test_radar.png');
        final Uint8List bytes = data.buffer.asUint8List();
        
        // ส่งเข้ากระบวนการกรองสี
        final processed = await _processRadarImage(bytes);
        if (mounted) setState(() => _processedRadarBytes = processed);
        debugPrint("🧪 TEST MODE: Loaded test_radar.png");
      } catch (e) {
        debugPrint("❌ Error loading test asset: $e");
        debugPrint("⚠️ อย่าลืมเอารูปใส่ assets และแก้ pubspec.yaml ด้วยครับ");
      }
      return;
    }

    // กรณีโหมดปกติ: ดึงจาก Server
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
            if (mounted) setState(() => _processedRadarBytes = processed);
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error radar fetch: $e");
    }
  }

  // ✅ ฟังก์ชันประมวลผลภาพ (Strict Mode: กรองป่า/เขา ออกหมด)
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
        
        // ตัดวงกลม
        if (dx * dx + dy * dy > radiusSquared) {
           masked.setPixelRgba(x, y, 0, 0, 0, 0); 
           continue;
        }

        final pixel = cropped.getPixel(x, y);

        // ตรวจสอบสี
        if (_isRainPixel(pixel)) {
          masked.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 210);
        } else {
          masked.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    return Uint8List.fromList(img.encodePng(masked));
  }

  // ✅ Logic กรองสีแบบเข้มงวด (Strict Mode)
  bool _isRainPixel(img.Pixel pixel) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    // 1. กรองสีตุ่นๆ/สีเทา
    final maxVal = max(r, max(g, b));
    final minVal = min(r, min(g, b));
    if ((maxVal - minVal) < 60) return false; 

    // 2. ฆ่าภูเขา (Red > Green แต่ Green สูง)
    if (r > g) {
      if (g > 80) return false; // ถ้าส้ม/น้ำตาล -> ตัดทิ้ง
    }

    // 3. ฆ่าป่า (Green > Red แต่ต่างกันไม่มาก)
    if (g > r) {
      if ((g - r) < 70) return false; // ถ้าเขียวชนะแดงไม่ขาด -> ตัดทิ้ง
      if (g < 130) return false;      // ถ้าเขียวมืด -> ตัดทิ้ง
    }

    // 4. Whitelist สีฝน
    bool isGreenRain = (g > 140) && (g > r + 70) && (g > b + 70);
    bool isYellowRain = (r > 150 && g > 150 && b < 80);
    bool isRedRain = (r > 150 && g < 80 && b < 80);

    return isGreenRain || isYellowRain || isRedRain;
  }

  // ... (ฟังก์ชัน Zoom, GPS, Reports เหมือนเดิม ไม่ต้องแก้) ...
  void _handleZoomIn() {
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _handleZoomOut() {
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  Future<void> _handleCurrentLocation() async {
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
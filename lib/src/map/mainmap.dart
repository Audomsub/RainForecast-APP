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
import '../popup/alertPopup.dart'; 

class MainMap extends StatefulWidget {
  const MainMap({super.key});

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
  // ✅ 1. สร้าง MapController ภายในตัว
  final MapController _mapController = MapController();

  // ✅ 2. ตัวแปรสำหรับระบบค้นหา
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  // --- ตัวแปรเดิมของ Map ---
  final DBService _dbService = DBService();
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _rainReports = [];
  late final RealtimeChannel _rainChannel;

  Uint8List? _processedRadarBytes;
  img.Image? _radarImageForLogic;
  Timer? _radarTimer;

  bool _isAlertShowing = false;
  DateTime? _lastAlertTime;

  final LatLng _radarCenter = const LatLng(18.163, 100.354);
  late LatLngBounds _radarBounds;

  @override
  void initState() {
    super.initState();
    _calculateRadarBounds();
    _fetchLatestRadar();

    _radarTimer = Timer.periodic(const Duration(minutes: 6), (timer) {
      _fetchLatestRadar();
    });

    _fetchReports();
    _subscribeToRainReports();
    _checkLocationPermission();
    
    // Listener เพื่ออัปเดต UI ปุ่มกากบาทเมื่อพิมพ์ข้อความ
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _searchController.dispose();
    _debounce?.cancel();
    Supabase.instance.client.removeChannel(_rainChannel);
    super.dispose();
  }

  // ==========================================
  // 🔍 SECTION: SEARCH LOGIC (ระบบค้นหา)
  // ==========================================
  
  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // 1. ตรวจสอบพิกัด (Lat, Lng)
    final RegExp coordRegExp = RegExp(r'^\s*([-+]?\d*\.?\d+)\s*[,\s]\s*([-+]?\d*\.?\d+)\s*$');
    final match = coordRegExp.firstMatch(query);

    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) {
        _moveToLocation(lat, lng);
        _clearSearchResults();
        return;
      }
    }

    // 2. ค้นหาชื่อสถานที่ (Photon API)
    setState(() => _isSearching = true);
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse('https://photon.komoot.io/api/?q=$encodedQuery&limit=5&lang=th');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _searchResults = data['features'] ?? [];
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (e) {
      setState(() => _isSearching = false);
      debugPrint("Search error: $e");
    }
  }

  void _selectPlace(dynamic feature) {
    final List coords = feature['geometry']['coordinates'];
    final double lng = coords[0].toDouble();
    final double lat = coords[1].toDouble();

    _moveToLocation(lat, lng);
    _clearSearchResults();
    FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ด
  }

  void _moveToLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 13.0);
  }

  void _clearSearchResults() {
    setState(() => _searchResults = []);
  }

  void _clearSearchText() {
    _searchController.clear();
    _clearSearchResults();
    FocusScope.of(context).unfocus();
  }

  // ==========================================
  // 📍 SECTION: LOCATION & RADAR LOGIC
  // ==========================================

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    _handleCurrentLocation();
    _startLocationStream();
  }

  void _startLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, 
    );
    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      LatLng newLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _currentLocation = newLoc);
        _checkUserLocationInRain(newLoc);
      }
    });
  }

  void _checkUserLocationInRain(LatLng userLocation) {
    if (_radarImageForLogic == null || _isAlertShowing) return;
    if (_lastAlertTime != null && DateTime.now().difference(_lastAlertTime!).inMinutes < 5) return;
    if (!_radarBounds.contains(userLocation)) return;

    double latRange = _radarBounds.north - _radarBounds.south;
    double lngRange = _radarBounds.east - _radarBounds.west;
    double xRatio = (userLocation.longitude - _radarBounds.west) / lngRange;
    double yRatio = (_radarBounds.north - userLocation.latitude) / latRange;

    int pixelX = (xRatio * _radarImageForLogic!.width).round();
    int pixelY = (yRatio * _radarImageForLogic!.height).round();

    if (pixelX < 0 || pixelX >= _radarImageForLogic!.width || 
        pixelY < 0 || pixelY >= _radarImageForLogic!.height) return;

    img.Pixel pixel = _radarImageForLogic!.getPixel(pixelX, pixelY);

    if (_isRainPixel(pixel)) {
       double intensity = 0.5;
       String rainLevel = "Moderate Rain";
       if (pixel.r > 200 && pixel.g < 100) {
         intensity = 0.9;
         rainLevel = "Heavy Rain";
       } else if (pixel.g > 200 && pixel.r < 150) {
         intensity = 0.3;
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
            if (mounted) setState(() => _isAlertShowing = false);
          },
          address: "ตำแหน่งปัจจุบันของคุณ", 
          intensity: intensity,
          probability: (intensity * 100).toInt(),
        );
      },
    );
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

  Future<void> _fetchLatestRadar() async {
    const String baseUrl = "https://rainforecast-app.onrender.com";
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/radar/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          String path = data['data']['filepath'];
          final imageResponse = await http.get(Uri.parse('$baseUrl$path'));
          if (imageResponse.statusCode == 200) {
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

  bool _isRainPixel(img.Pixel pixel) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();
    if (pixel.a == 0) return false;
    final maxVal = max(r, max(g, b));
    final minVal = min(r, min(g, b));
    if ((maxVal - minVal) < 60) return false; 
    if (r > g) { if (g > 80) return false; }
    if (g > r) { if ((g - r) < 70) return false; if (g < 130) return false; }
    bool isGreenRain = (g > 140) && (g > r + 70) && (g > b + 70);
    bool isYellowRain = (r > 150 && g > 150 && b < 80);
    bool isRedRain = (r > 150 && g < 80 && b < 80);
    return isGreenRain || isYellowRain || isRedRain;
  }

  void _handleZoomIn() {
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, min(currentZoom + 1, 15.0));
  }

  void _handleZoomOut() {
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, max(currentZoom - 1, 4.0));
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
    _rainChannel = Supabase.instance.client.channel('public:rain_reports').onPostgresChanges(
        event: PostgresChangeEvent.insert, schema: 'public', table: 'rain_reports',
        callback: (payload) => _fetchReports(),
      ).subscribe();
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
        // ------------------ LAYER 1: MAP ------------------
        FlutterMap(
          mapController: _mapController, 
          options: MapOptions(
            initialCenter: const LatLng(13.7563, 100.5018),
            initialZoom: 6.0,
            minZoom: 4.0,  
            maxZoom: 15.0, 
            onTap: (_, __) {
              if (_searchResults.isNotEmpty || _searchController.text.isNotEmpty) {
                 _clearSearchResults();
                 FocusScope.of(context).unfocus();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        // ------------------ LAYER 2: SEARCH BAR ------------------
        Positioned(
          top: 60,
          left: 20,
          right: 90, 
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาตำบล, อำเภอ, จังหวัด...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.location_on_rounded, color: Color(0xFF6C63FF)),
                    
                    // ✅✅✅ ส่วนปุ่ม SUBMIT และ CLEAR ✅✅✅
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: _clearSearchText,
                            ),
                          // ปุ่ม Submit สีม่วง
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C63FF),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.search, color: Colors.white, size: 20),
                              onPressed: _performSearch, // กดปุ่มนี้จะค้นหาทันที
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              
              // ผลการค้นหา (Dropdown List)
              if (_searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final feature = _searchResults[index];
                      final props = feature['properties'];
                      String title = props['name'] ?? 'ไม่ทราบชื่อ';
                      List<String> subParts = [
                        props['district'] ?? '',
                        props['city'] ?? '',
                        props['state'] ?? '',
                      ];
                      subParts.removeWhere((s) => s.isEmpty || s == title);

                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place, color: Colors.grey, size: 20),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: subParts.isNotEmpty ? Text(subParts.join(', ')) : null,
                        onTap: () => _selectPlace(feature),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // ------------------ LAYER 3: CONTROLS ------------------
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
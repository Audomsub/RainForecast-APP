import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Import Supabase
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
  final ImagePicker _picker = ImagePicker();
  
  LatLng? _searchMarker;
  LatLng? _currentLocation;
  
  final List<LatLng> _userTempPins = [];
  List<Map<String, dynamic>> _rainReports = [];

  // ✅ ตัวแปรสำหรับ Realtime Subscription
  late final RealtimeChannel _rainChannel; 

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _handleCurrentLocation();
    
    // ✅ 1. เริ่มฟัง Realtime Changes จาก Supabase
    _subscribeToRainReports();
  }

  @override
  void dispose() {
    // ✅ 2. ยกเลิกการฟังเมื่อปิดหน้า
    Supabase.instance.client.removeChannel(_rainChannel);
    super.dispose();
  }

  // ✅ ฟังก์ชันฟัง Realtime
  void _subscribeToRainReports() {
    _rainChannel = Supabase.instance.client
      .channel('public:rain_reports')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'rain_reports',
        callback: (payload) {
          print('⚡ Realtime Update: มีจุดฝนตกใหม่!');
          // เมื่อมีข้อมูลใหม่ ให้โหลดข้อมูลใหม่ทั้งหมดมาแสดง
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

  // ✅ ปรับปรุงการดึงข้อมูล
  Future<void> _fetchReports() async {
    // 1. ลองดึงจาก Supabase ก่อน (เห็นของคนอื่น)
    List<Map<String, dynamic>> reports = await _dbService.getSupabaseReports();
    
    // 2. ถ้าดึงไม่ได้ (เน็ตหลุด) หรือไม่มีข้อมูล ให้ดึงจาก SQLite (Offline)
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

  Future<void> _onNotifyRainPressed() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเปิด GPS')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = userLatLng;
        _userTempPins.add(userLatLng);
      });

      _mapController.move(userLatLng, 15);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📍 ปักหมุดที่ตำแหน่งของคุณแล้ว แตะที่หมุดเพื่อแจ้งรายละเอียด')),
        );
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('หาตำแหน่งไม่เจอ กรุณาลองใหม่')));
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _userTempPins.add(point);
    });
  }

  void _removeTempPin(LatLng point) {
    setState(() {
      _userTempPins.remove(point);
    });
  }

  void _showAddReportDialog(LatLng targetPoint) async {
    final categories = await _dbService.getCategories();
    if (categories.isEmpty) return; 

    int? selectedCatId = categories[0]['id'] as int;
    final descCtrl = TextEditingController();
    XFile? _selectedImage;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('แจ้งจุดฝนตก 🌧️'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setDialogState(() => _selectedImage = image);
                        }
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                  Text("เพิ่มรูปภาพ (ถ้ามี)", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    DropdownButtonFormField<int>(
                      value: selectedCatId,
                      decoration: const InputDecoration(labelText: 'สภาพอากาศ'),
                      items: categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'] as int,
                          child: Row(
                            children: [
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: Color(cat['color_value']),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(cat['name']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedCatId = val),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียด',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                  onPressed: () async {
                    if (selectedCatId != null) {
                      // ✅ เรียก addReport ซึ่งจะบันทึกทั้ง SQLite และ Supabase
                      await _dbService.addReport(
                        targetPoint.latitude,
                        targetPoint.longitude,
                        selectedCatId!,
                        descCtrl.text,
                        "User_${DateTime.now().second}", // อาจเปลี่ยนเป็นชื่อ user จริงถ้ามี login
                        _selectedImage?.path,
                      );
                      Navigator.pop(context);
                      
                      setState(() {
                        _userTempPins.remove(targetPoint);
                      });
                      
                      // เรียกโหลดใหม่ทันที (ซึ่งจะไปดึงจาก Online หรือ Offline ก็แล้วแต่สถานะ)
                      _fetchReports();
                    }
                  },
                  child: const Text('แจ้งทันที', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
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
              // หมายเหตุ: รูปภาพจาก Supabase อาจต้องใช้ Image.network แทน Image.file
              // ในโค้ดนี้ยังรองรับ Image.file (Local) เป็นหลัก
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
            onTap: _onMapTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.rainforecast_app',
            ),
            
            MarkerLayer(
              markers: _userTempPins.map((point) {
                return Marker(
                  point: point,
                  width: 50,
                  height: 50,
                  child: GestureDetector(
                    onTap: () => _showAddReportDialog(point),
                    onLongPress: () => _removeTempPin(point),
                    child: const Icon(
                      Icons.location_on, 
                      color: Colors.blueAccent, 
                      size: 50,
                      shadows: [Shadow(blurRadius: 5, color: Colors.black45)],
                    ),
                  ),
                );
              }).toList(),
            ),

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
          right: 16, bottom: 120, 
          child: MapControlBar(
            onZoomIn: _handleZoomIn,
            onZoomOut: _handleZoomOut,
            onCurrentLocation: _handleCurrentLocation,
          ),
        ),

        Positioned(
          bottom: 120,
          left: 20,
          child: FloatingActionButton.extended(
            heroTag: 'notify_rain',
            backgroundColor: const Color(0xFF6C63FF),
            onPressed: _onNotifyRainPressed, 
            icon: const Icon(Icons.add_location_alt, color: Colors.white),
            label: const Text("แจ้งจุดฝนตก", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
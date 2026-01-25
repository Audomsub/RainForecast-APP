import 'dart:io'; // ใช้แสดงรูป
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart'; // ✅ Import image picker
import 'package:rainforecast_app/src/service/db_service.dart';
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
  final ImagePicker _picker = ImagePicker(); // ตัวเลือกรูป
  
  LatLng? _searchMarker;
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _rainReports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _fetchReports();
    });
  }

  Future<void> _fetchReports() async {
    final reports = await _dbService.getActiveReports();
    setState(() => _rainReports = reports);
  }

  // --- Dialog เพิ่มรายงาน + รูปภาพ ---
  void _showAddReportDialog() async {
    final categories = await _dbService.getCategories();
    if (categories.isEmpty) return; 

    int? selectedCatId = categories[0]['id'] as int;
    final descCtrl = TextEditingController();
    XFile? _selectedImage; // ตัวแปรเก็บรูปที่เลือก
    
    LatLng targetPos = _currentLocation ?? _mapController.camera.center;

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
                    // เลือกรูปภาพ
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
                      await _dbService.addReport(
                        targetPos.latitude,
                        targetPos.longitude,
                        selectedCatId!,
                        descCtrl.text,
                        "User_${DateTime.now().second}",
                        _selectedImage?.path, // ✅ ส่ง path รูปภาพไปด้วย
                      );
                      Navigator.pop(context);
                      _fetchReports();
                    }
                  },
                  child: const Text('ส่งรายงาน', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Modal แสดงรายละเอียด + รูปภาพ ---
  void _showReportDetail(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ให้ขยายเต็มจอได้ถ้ารูปใหญ่
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
              // ถ้ามีรูป ให้แสดงรูปก่อน
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

  // ... (ฟังก์ชันเดิมอื่นๆ คงไว้เหมือนเดิม) ...
  void _handleZoomIn() {
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _handleZoomOut() {
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  Future<void> _handleCurrentLocation() async {
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
      try {
        Position position = await Geolocator.getCurrentPosition();
        LatLng userLatLng = LatLng(position.latitude, position.longitude);
        setState(() => _currentLocation = userLatLng);
        _mapController.move(userLatLng, 15);
      } catch (e) {
        debugPrint("Error: $e");
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
  void didUpdateWidget(covariant MainMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchText.isNotEmpty && widget.searchText != oldWidget.searchText) {
      _searchLocation(widget.searchText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(13.7563, 100.5018),
            initialZoom: 9.2,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.rainforecast_app',
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
            heroTag: 'report_rain',
            backgroundColor: const Color(0xFF6C63FF),
            onPressed: _showAddReportDialog,
            icon: const Icon(Icons.add_a_photo, color: Colors.white),
            label: const Text("แจ้งจุดฝนตก", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
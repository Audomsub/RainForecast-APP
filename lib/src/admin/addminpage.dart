import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/service/db_service.dart';
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final DBService _dbService = DBService();
  Timer? _timer;

  List<Map<String, dynamic>> _stats = [];
  List<Map<String, dynamic>> _radarLogs = [];
  int _onlineCount = 0;

  final String _adminDeviceId = "admin_${DateTime.now().millisecondsSinceEpoch}";

  // ✅ ตั้งค่า Base URL (เปลี่ยน IP ตามเครื่อง Server ของคุณ)
  // - Android Emulator: "http://10.0.2.2:3000"
  // - iOS Simulator: "http://localhost:3000"
  // - เครื่องจริง (Wi-Fi เดียวกัน): "http://192.168.1.xxx:3000"
  final String _baseUrl = "http://10.0.2.2:3000";

  @override
  void initState() {
    super.initState();
    _loadData();

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted) {
        await _dbService.sendHeartbeat(_adminDeviceId);
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final stats = await _dbService.getTrafficStats();
      final online = await _dbService.getOnlineCount();
      final radarLogs = await _dbService.getRadarHistory();

      if (mounted) {
        setState(() {
          _stats = stats;
          _onlineCount = online;
          _radarLogs = radarLogs;
        });
      }
    } catch (e) {
      debugPrint("Error loading admin stats: $e");
    }
  }

  // ✅ ฟังก์ชันแสดง Dialog รูปภาพจาก URL
  void _showRadarImageDialog(String filename, String? filepath) {
    if (filepath == null || filepath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image path not found")),
      );
      return;
    }

    // สร้าง URL สมบูรณ์
    final imageUrl = "$_baseUrl$filepath";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        filename,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
              const Divider(height: 1),
              // Image Area (โหลดจาก URL)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text("Failed to load image"),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Live Traffic Monitor',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent[700],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "$_onlineCount Online",
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSummaryCard(),
            const SizedBox(height: 20),
            _buildHourlyTrafficGraph(),
            const SizedBox(height: 20),
            _buildRadarHistorySection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyTrafficGraph() {
    if (_stats.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(
            child: Text("Waiting for traffic data...",
                style: TextStyle(color: Colors.grey))),
      );
    }

    List<FlSpot> spots = [];
    try {
      spots = _stats.map((s) {
        DateTime time = DateTime.parse(s['timestamp']).toLocal();
        double xValue = time.hour + (time.minute / 60.0);
        return FlSpot(xValue, (s['user_count'] as num).toDouble());
      }).toList();
      spots.sort((a, b) => a.x.compareTo(b.x));
    } catch (e) {
      return Center(child: Text("Data Error: $e"));
    }

    double maxCount = spots.isEmpty
        ? 5
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (maxCount < 5) maxCount = 5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Traffic Trends",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.5,
            child: LineChart(
              LineChartData(
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 24,
                minY: 0,
                maxY: maxCount * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF6C63FF),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    int totalHits =
        _stats.fold(0, (sum, item) => sum + (item['user_count'] as num).toInt());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(
              "Total Activity", "$totalHits", Icons.touch_app, Colors.white),
          Container(width: 1, height: 40, color: Colors.white24),
          _summaryItem("System Status", "Normal", Icons.cloud_done,
              Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String title, String value, IconData icon, Color iconColor) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 5),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildRadarHistorySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Radar Logs History",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_radarLogs.length} Records",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          if (_radarLogs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off,
                        size: 40, color: Colors.grey),
                    SizedBox(height: 10),
                    Text("No radar data available",
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _radarLogs.length > 15 ? 15 : _radarLogs.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 20, color: Colors.black12),
              itemBuilder: (context, index) {
                final log = _radarLogs[index];
                final filename = log['filename'] ?? 'Unknown File';
                final filepath = log['filepath'];
                final timestampStr = log['created_at'] ?? '';

                // สร้าง URL สำหรับ Thumbnail และ Dialog
                final fullImageUrl = (filepath != null && filepath.isNotEmpty) 
                    ? "$_baseUrl$filepath" 
                    : "";

                String timeDisplay = "Unknown Time";

                // Logic แปลงเวลา
                if (filename.toString().contains('_')) {
                  try {
                    final parts = filename.toString().split('_');
                    if (parts.length > 1) {
                      final tsStr = parts[1].split('.')[0];
                      final ts = int.tryParse(tsStr);
                      if (ts != null) {
                        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                        timeDisplay = DateFormat('HH:mm:ss (dd MMM)').format(dt);
                      }
                    }
                  } catch (_) {}
                }
                if (timeDisplay == "Unknown Time" && timestampStr.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(timestampStr).toLocal();
                    timeDisplay = DateFormat('HH:mm:ss (dd MMM)').format(dt);
                  } catch (_) {}
                }

                return InkWell(
                  onTap: () {
                    // เปิด Dialog ดูรูปใหญ่
                    _showRadarImageDialog(filename, filepath);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        // ✅ ปรับเปลี่ยน: แสดง Thumbnail รูปภาพแทน Icon
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (fullImageUrl.isNotEmpty)
                                ? Image.network(
                                    fullImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.radar, 
                                          color: Colors.orange, size: 24);
                                    },
                                  )
                                : const Icon(Icons.radar, 
                                    color: Colors.orange, size: 24),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filename,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Imported: $timeDisplay",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.visibility,
                                  size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                "View",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
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

  final String _adminDeviceId =
      "admin_${DateTime.now().millisecondsSinceEpoch}";

  // ✅ ตั้งค่า Base URL (ตรวจสอบ IP ให้ตรงกับ Server ของคุณ)
  // Render: "https://rainforecast-app.onrender.com"
  // Local Android: "http://10.0.2.2:3000"
  final String _baseUrl = "https://rainforecast-app.onrender.com";

  @override
  void initState() {
    super.initState();
    _loadData();

    // ส่ง Heartbeat และดึงข้อมูลใหม่ทุก 3 วินาที
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
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

  // ✅ ฟังก์ชันแสดง Dialog รูปภาพขนาดใหญ่ (ซูมและเลื่อนได้)
  void _showRadarImageDialog(String filename, String? filepath) {
    if (filepath == null || filepath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("ไม่พบไฟล์รูปภาพในระบบ")));
      return;
    }

    // รวม URL: ตรวจสอบการใส่ Slash เพื่อไม่ให้ URL พัง
    final String imageUrl = filepath.startsWith('/')
        ? "$_baseUrl$filepath"
        : "$_baseUrl/$filepath";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black, // ใช้สีดำเพื่อให้ภาพเด่น
        insetPadding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            // ส่วนแสดงรูปภาพที่ซูมได้
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const CircularProgressIndicator(
                        color: Colors.white,
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 64,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "โหลดรูปภาพไม่สำเร็จ",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ปุ่มปิดมุมขวาบน
            Positioned(
              top: 15,
              right: 15,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // ชื่อไฟล์ด้านล่าง
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Text(
                filename,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
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
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [_buildOnlineStatusIndicator()],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }

  Widget _buildOnlineStatusIndicator() {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
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
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "$_onlineCount Online",
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyTrafficGraph() {
    if (_stats.isEmpty) {
      return _buildEmptyContainer("Waiting for traffic data...");
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
      return _buildEmptyContainer("Data formatting error");
    }

    double maxCount = spots.isEmpty
        ? 5
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (maxCount < 5) maxCount = 5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Traffic Trends",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.7,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 24,
                minY: 0,
                maxY: maxCount * 1.3,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF6C63FF),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                    ),
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
    int totalHits = _stats.fold(
      0,
      (sum, item) => sum + (item['user_count'] as num).toInt(),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8E87FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem("Total Activity", "$totalHits", Icons.analytics),
          Container(width: 1, height: 30, color: Colors.white24),
          _summaryItem("System Status", "Normal", Icons.check_circle_outline),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildRadarHistorySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Radar Logs History",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_radarLogs.isEmpty)
            const Center(
              child: Text(
                "No records found",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _radarLogs.length > 10 ? 10 : _radarLogs.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 25, color: Colors.black12),
              itemBuilder: (context, index) {
                final log = _radarLogs[index];
                final String filename = log['filename'] ?? 'Unknown';
                final String? filepath = log['filepath'];
                final String imageUrl = filepath != null
                    ? "$_baseUrl$filepath"
                    : "";

                return InkWell(
                  onTap: () => _showRadarImageDialog(filename, filepath),
                  child: Row(
                    children: [
                      _buildThumbnail(imageUrl),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              filename,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "คลิกเพื่อดูภาพขยาย",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.zoom_in, size: 20, color: Colors.grey),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String url) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.image_not_supported, size: 20),
              )
            : const Icon(Icons.radar, color: Colors.orange, size: 20),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _buildEmptyContainer(String text) => Container(
    height: 150,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: _cardDecoration(),
    child: Center(
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    ),
  );
}

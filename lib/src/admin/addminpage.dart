import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/service/db_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final DBService _dbService = DBService();
  Timer? _timer;

  List<Map<String, dynamic>> _stats = [];
  int _onlineCount = 0;

  final String _adminDeviceId =
      "admin_${DateTime.now().millisecondsSinceEpoch}";

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

      if (mounted) {
        setState(() {
          _stats = stats;
          _onlineCount = online;
        });
      }
    } catch (e) {
      debugPrint("Error loading admin stats: $e");
    }
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyTrafficGraph() {
    if (_stats.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.bar_chart, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                "Waiting for traffic data...",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    List<FlSpot> spots = [];

    try {
      spots = _stats.map((s) {
        DateTime time =
            DateTime.parse(s['timestamp']).toLocal();
        double xValue =
            time.hour + (time.minute / 60.0);

        return FlSpot(
          xValue,
          (s['user_count'] as num).toDouble(),
        );
      }).toList();

      spots.sort((a, b) => a.x.compareTo(b.x));
    } catch (e) {
      return Center(child: Text("Data Error: $e"));
    }

    double maxCount = spots.isEmpty
        ? 5
        : spots
            .map((e) => e.y)
            .reduce((a, b) => a > b ? a : b);

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
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Traffic Trends",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                    dotData: FlDotData(show: false),
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
      (sum, item) =>
          sum + (item['user_count'] as num).toInt(),
    );

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
            "Total Activity",
            "$totalHits",
            Icons.touch_app,
            Colors.white,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          _summaryItem(
            "System Status",
            "Normal",
            Icons.cloud_done,
            Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 5),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

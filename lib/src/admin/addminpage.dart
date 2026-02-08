import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/service/db_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  final DBService _dbService = DBService();
  late TabController _tabController;
  Timer? _timer;

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _stats = [];
  int _onlineCount = 0; 
  final String _adminDeviceId = "admin_${DateTime.now().millisecondsSinceEpoch}";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
    
    // Set Timer to update data every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted) {
        await _dbService.sendHeartbeat(_adminDeviceId); 
        _loadAllData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); 
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final reports = await _dbService.getAllReportsForAdmin();
    final users = await _dbService.getUniqueUsers();
    
    // Fetch traffic stats from online history instead of report counts
    final stats = await _dbService.getTrafficStats(); 
    final online = await _dbService.getOnlineCount();
    
    if (mounted) {
      setState(() {
        _reports = reports;
        _users = users;
        _stats = stats;
        _onlineCount = online;
      });
    }
  }

  Future<void> _deleteReport(int id) async {
    await _dbService.deleteReport(id);
    await _loadAllData();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report deleted')));
  }

  Future<void> _editReport(Map<String, dynamic> report) async {
    final categories = await _dbService.getCategories();
    final descCtrl = TextEditingController(text: report['description']);
    int selectedCatId = report['category_id'];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        int tempCatId = selectedCatId;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Report'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: tempCatId,
                    decoration: const InputDecoration(labelText: 'Weather Condition'),
                    items: categories.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['id'] as int,
                        child: Text(cat['name']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => tempCatId = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    await _dbService.updateReport(report['report_id'], tempCatId, descCtrl.text);
                    Navigator.pop(context);
                    await _loadAllData();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 10), 
                const SizedBox(width: 8),
                Text(
                  "Online: $_onlineCount", 
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6C63FF),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: "Reports"),
            Tab(icon: Icon(Icons.people), text: "Users"),
            Tab(icon: Icon(Icons.show_chart), text: "Traffic"), 
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsList(),
          _buildUsersList(),
          _buildHourlyTrafficGraph(),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    if (_reports.isEmpty) return const Center(child: Text("No reports available"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(report['color_value']).withOpacity(0.2),
              child: Icon(IconData(report['icon_code'], fontFamily: 'MaterialIcons'), 
                        color: Color(report['color_value'])),
            ),
            title: Text(report['cat_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("User: ${report['reporter_name']}"),
                Text(report['description'] ?? "-"),
                if (report['image_path'] != null)
                   Text(" Image attached", style: TextStyle(color: Colors.blue[700], fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange), 
                  onPressed: () => _editReport(report),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () => _deleteReport(report['report_id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) return const Center(child: Text("No user data available"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.1),
              child: const Icon(Icons.person, color: Colors.purple),
            ),
            title: Text(user['reporter_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Last active: ${user['last_active'].substring(0, 16).replaceFirst('T', ' ')}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text("${user['report_count']} Reports", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHourlyTrafficGraph() {
    if (_stats.isEmpty) return const Center(child: CircularProgressIndicator());

    List<FlSpot> spots = _stats.map((s) {
      return FlSpot(double.parse(s['hour']), s['count'].toDouble());
    }).toList();

    double maxCount = _stats.map((s) => s['count'] as int).reduce((a, b) => a > b ? a : b).toDouble();
    if (maxCount < 5) maxCount = 5;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("User Traffic Statistics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Displays user density based on time intervals", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          
          AspectRatio(
            aspectRatio: 1.5,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4, 
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text('${value.toInt()}:00', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF6C63FF),
                    barWidth: 4,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF6C63FF),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                    ),
                  ),
                ],
                minX: 0,
                maxX: 23,
                minY: 0,
                maxY: maxCount + 1,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    int currentTotal = _stats.fold(0, (sum, item) => sum + (item['count'] as int));
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem("Today's Total", currentTotal.toString(), Icons.history),
            const VerticalDivider(),
            _summaryItem("Backend Status", "Online", Icons.cloud_done, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String title, String value, IconData icon, {Color color = const Color(0xFF6C63FF)}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
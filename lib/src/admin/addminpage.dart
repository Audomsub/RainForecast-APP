import 'dart:async';
import 'dart:io';
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
    final stats = await _dbService.getHourlyStats();
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
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบรายงานแล้ว')));
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
              title: const Text('แก้ไขรายงาน'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: tempCatId,
                    decoration: const InputDecoration(labelText: 'สภาพอากาศ'),
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
                    decoration: const InputDecoration(labelText: 'รายละเอียด'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
                ElevatedButton(
                  onPressed: () async {
                    await _dbService.updateReport(report['report_id'], tempCatId, descCtrl.text);
                    Navigator.pop(context);
                    await _loadAllData();
                  },
                  child: const Text('บันทึก'),
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
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.black)),
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
            Tab(icon: Icon(Icons.bar_chart), text: "Activity"),
          ],
        ),
      ),
      
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsList(),
          _buildUsersList(),
          _buildHourlyStats(),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    if (_reports.isEmpty) return const Center(child: Text("ยังไม่มีรายงานเข้ามา"));
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
                   Text(" มีรูปภาพแนบ", style: TextStyle(color: Colors.blue[700], fontSize: 12)),
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
    if (_users.isEmpty) return const Center(child: Text("ยังไม่มีข้อมูลผู้ใช้"));
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
            subtitle: Text("ใช้งานล่าสุด: ${user['last_active'].substring(0, 16).replaceFirst('T', ' ')}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text("${user['report_count']} รายงาน", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHourlyStats() {
    if (_stats.isEmpty) return const Center(child: Text("ไม่มีข้อมูลสถิติ"));
    
    List<int> hourlyCounts = List.filled(24, 0);
    for (var s in _stats) {
      int hour = int.parse(s['hour']);
      hourlyCounts[hour] = s['count'];
    }

    int maxCount = hourlyCounts.reduce((curr, next) => curr > next ? curr : next);
    if (maxCount == 0) maxCount = 1;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ความหนาแน่นการใช้งานรายชั่วโมง", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 24,
              itemBuilder: (context, index) {
                final count = hourlyCounts[index];
                final heightFactor = count / maxCount;
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (count > 0) 
                      Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 5),
                    Container(
                      width: 20,
                      height: 180 * heightFactor + 10,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: count > 0 ? const Color(0xFF6C63FF) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("$index:00", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Text("ช่วงเวลา (นาฬิกา)", style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}
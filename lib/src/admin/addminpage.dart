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

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _stats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final reports = await _dbService.getAllReportsForAdmin();
    final users = await _dbService.getUniqueUsers();
    final stats = await _dbService.getHourlyStats();
    
    setState(() {
      _reports = reports;
      _users = users;
      _stats = stats;
    });
  }

  Future<void> _deleteReport(int id) async {
    await _dbService.deleteReport(id);
    _loadAllData();
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
                    await _dbService.updateReport(report['id'], tempCatId, descCtrl.text);
                    Navigator.pop(context);
                    _loadAllData();
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
          // --- Tab 1: Manage Reports ---
          _buildReportsList(),

          // --- Tab 2: All Users ---
          _buildUsersList(),

          // --- Tab 3: Hourly Stats ---
          _buildHourlyStats(),
        ],
      ),
    );
  }

  // Widget 1: รายการรายงาน (เหมือนเดิม)
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
                   Text("📷 มีรูปภาพแนบ", style: TextStyle(color: Colors.blue[700], fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editReport(report)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteReport(report['id'])),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget 2: รายชื่อผู้ใช้ทั้งหมด
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

  // Widget 3: สถิติตามช่วงเวลา (Hourly Stats)
  Widget _buildHourlyStats() {
    if (_stats.isEmpty) return const Center(child: Text("ไม่มีข้อมูลสถิติ"));
    
    // เตรียมข้อมูล 24 ชั่วโมง (0-23)
    List<int> hourlyCounts = List.filled(24, 0);
    for (var s in _stats) {
      int hour = int.parse(s['hour']);
      hourlyCounts[hour] = s['count'];
    }

    // หาค่าสูงสุดเพื่อคำนวณความสูงกราฟ
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
                      height: 200 * heightFactor + 10, // ความสูงกราฟขั้นต่ำ 10
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
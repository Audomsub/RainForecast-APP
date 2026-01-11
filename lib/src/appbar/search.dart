import 'package:flutter/material.dart';

// ลบ void main() ทิ้งไปเลยครับ เราไม่ได้รันไฟล์นี้ตรงๆ

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  // ลบ logic เปลี่ยน Theme ออกก่อนนะครับ เพราะมันต้องแก้ที่ main.dart ใหญ่
  
  @override
  Widget build(BuildContext context) {
    // ลบ MaterialApp และ Scaffold ออก
    // ส่งคืน SearchAnchor ตรงๆ เลย เพื่อให้มันไปอยู่ในกรอบของ AppBar ได้
    return SearchAnchor(
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          hintText: 'ค้นหา...', // ใส่ข้อความแนะนำ
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 16.0),
          ),
          onTap: () {
            controller.openView();
          },
          onChanged: (_) {
            controller.openView();
          },
          leading: const Icon(Icons.search),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) {
        return List<ListTile>.generate(5, (int index) {
          final String item = 'สถานที่ $index';
          return ListTile(
            title: Text(item),
            onTap: () {
              setState(() {
                controller.closeView(item);
              });
            },
          );
        });
      },
    );
  }
}
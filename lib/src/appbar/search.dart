import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SearchBarWidget extends StatefulWidget {
  final Function(double lat, double lng) onGoToLocation;

  const SearchBarWidget({
    super.key,
    required this.onGoToLocation,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() => _loading = true);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=$query&format=json&limit=5',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'rainforecast_app'},
    );

    if (response.statusCode == 200) {
      setState(() {
        _results = json.decode(response.body);
        _loading = false;
      });
    }
  }

  void _selectPlace(dynamic place) {
    final lat = double.parse(place['lat']);
    final lon = double.parse(place['lon']);

    widget.onGoToLocation(lat, lon);

    setState(() {
      _results = [];
    });

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาสถานที่',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(), // ⌨ Enter
                ),
              ),

              // 🔍 ปุ่มค้นหา (เห็นแน่นอน)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search, // 👆 กดปุ่ม
              ),
            ],
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),

          if (_results.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final place = _results[index];
                return ListTile(
                  title: Text(
                    place['display_name'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectPlace(place),
                );
              },
            ),
        ],
      ),
    );
  }
}

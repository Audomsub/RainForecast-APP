import 'dart:async';
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
  Timer? _debounce;

  // ==============================
  // ตรวจสอบ Lat,Lng
  // ==============================
  bool _isCoordinates(String query) {
    final RegExp coordRegExp =
        RegExp(r'^\s*([-+]?\d*\.?\d+)\s*[,\s]\s*([-+]?\d*\.?\d+)\s*$');
    return coordRegExp.hasMatch(query);
  }

  // ==============================
  // SEARCH FUNCTION
  // ==============================
  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    // --- 1) ถ้าเป็นพิกัด ---
    if (_isCoordinates(query)) {
      final match = RegExp(
              r'^\s*([-+]?\d*\.?\d+)\s*[,\s]\s*([-+]?\d*\.?\d+)\s*$')
          .firstMatch(query);

      if (match != null) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);

        if (lat != null && lng != null) {
          widget.onGoToLocation(lat, lng);
          _clearSearch();
          return;
        }
      }
    }

    // --- 2) ค้นหาผ่าน Photon ---
    setState(() => _loading = true);

    try {
      final encodedQuery = Uri.encodeComponent(query);

      // จำกัดเฉพาะประเทศไทย + ภาษาไทย
      final url = Uri.parse(
          'https://photon.komoot.io/api/?q=$encodedQuery&limit=10&lang=th&osm_tag=place');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        setState(() {
          _results = data['features'] ?? [];
          _loading = false;
        });

        if (_results.isEmpty) {
          _showError('ไม่พบสถานที่');
        }
      } else {
        _showError('Server Error (${response.statusCode})');
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('การค้นหาขัดข้อง กรุณาลองใหม่');
    }
  }

  // ==============================
  void _selectPlace(dynamic feature) {
    final List coords = feature['geometry']['coordinates'];
    final double lng = coords[0].toDouble();
    final double lat = coords[1].toDouble();

    widget.onGoToLocation(lat, lng);
    _clearSearch();
  }

  void _clearSearch() {
    setState(() => _results = []);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ==============================
  // Debounce ป้องกันยิง API รัว
  // ==============================
  void _onChanged(String value) {
    setState(() {});

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ==============================
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'ค้นหาหมู่บ้าน, อำเภอ หรือ พิกัด...',
              prefixIcon:
                  const Icon(Icons.search, color: Colors.blueAccent),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 15),
            ),
            onSubmitted: (_) => _search(),
            onChanged: _onChanged,
          ),

          if (_loading)
            const LinearProgressIndicator(height: 2),

          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: 350),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final feature = _results[index];
                  final props = feature['properties'];

                  String title =
                      props['name'] ?? 'ไม่ทราบชื่อ';

                  List<String> subParts = [
                    props['district'] ??
                        props['city'] ??
                        '',
                    props['state'] ?? '',
                    props['country'] ?? '',
                  ]..removeWhere(
                      (s) => s.isEmpty || s == title);

                  return ListTile(
                    leading: const Icon(
                        Icons.location_on_outlined,
                        color: Colors.redAccent),
                    title: Text(title,
                        style: const TextStyle(
                            fontWeight:
                                FontWeight.w600)),
                    subtitle: Text(
                      subParts.join(', '),
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                    onTap: () =>
                        _selectPlace(feature),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

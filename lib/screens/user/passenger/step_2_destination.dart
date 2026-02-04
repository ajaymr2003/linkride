import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PassengerStepDestination extends StatefulWidget {
  const PassengerStepDestination({super.key});

  @override
  State<PassengerStepDestination> createState() => _PassengerStepDestinationState();
}

class _PassengerStepDestinationState extends State<PassengerStepDestination> {
  final TextEditingController _controller = TextEditingController();
  final MapController _mapController = MapController();
  
  List<dynamic> _locationResults = [];
  bool _showMap = false;
  LatLng _center = const LatLng(11.2588, 75.7804); 
  String _address = "";
  Timer? _debounce;

  // Store result temporarily before confirming
  Map<String, dynamic>? _selectedData;

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) { setState(() => _locationResults = []); return; }
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=in');
      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});
      if (response.statusCode == 200 && mounted) {
        setState(() => _locationResults = json.decode(response.body));
      }
    } catch (_) {}
  }

  void _selectResult(double lat, double lon, String name) {
    setState(() {
      _center = LatLng(lat, lon);
      _address = name;
      _controller.text = name;
      _showMap = true;
      _locationResults = [];
      
      // Store Lat/Lng
      _selectedData = {
        'name': name,
        'lat': lat,
        'lng': lon
      };
    });
    Future.delayed(const Duration(milliseconds: 100), () => _mapController.move(_center, 15));
  }

  // --- REVERSE GEOCODING (When dragging map) ---
  Future<void> _getAddressFromCoords(LatLng point) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18');
      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String name = data['display_name'].split(',').take(2).join(',').trim();
        if(mounted) {
          setState(() {
            _address = name;
            _controller.text = name;
            _selectedData = {
              'name': name,
              'lat': point.latitude,
              'lng': point.longitude
            };
          });
        }
      }
    } catch (_) {}
  }

  void _onMapInteractionEnd(MapEvent event) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _getAddressFromCoords(_mapController.camera.center);
    });
  }

  void _onConfirm() {
    if (_selectedData != null) {
      Navigator.pop(context, _selectedData);
    } else {
      // Fallback if typed but not selected (unsafe but prevents crash)
      Navigator.pop(context, {'name': _controller.text, 'lat': 0.0, 'lng': 0.0});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Going to", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          if (_showMap)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center, 
                initialZoom: 15,
                onMapEvent: (event) {
                  if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
                    _onMapInteractionEnd(event);
                  }
                },
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
              ],
            ),

          Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(15),
                child: TextField(
                  controller: _controller,
                  onChanged: (v) {
                    if (_showMap) setState(() => _showMap = false);
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () => _searchLocation(v));
                  },
                  decoration: InputDecoration(
                    hintText: "Search destination",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _showMap ? IconButton(icon: const Icon(Icons.close), onPressed: () { _controller.clear(); setState(() => _showMap = false); }) : null,
                    filled: true, fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (!_showMap)
                Expanded(
                  child: ListView.separated(
                    itemCount: _locationResults.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = _locationResults[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(p['display_name'].split(',')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(p['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectResult(double.parse(p['lat']), double.parse(p['lon']), p['display_name'].split(',')[0]),
                      );
                    },
                  ),
                ),
            ],
          ),

          if (_showMap)
             const Center(child: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.location_on, size: 50, color: Colors.red))),

          if (_showMap)
            Positioned(
              bottom: 30, left: 20, right: 20,
              child: ElevatedButton(
                onPressed: _onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF11A860),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("CONFIRM DESTINATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
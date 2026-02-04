import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RideStepDestination extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;

  const RideStepDestination({super.key, required this.onLocationSelected});

  @override
  State<RideStepDestination> createState() => _RideStepDestinationState();
}

class _RideStepDestinationState extends State<RideStepDestination> {
  final TextEditingController _controller = TextEditingController();
  final MapController _mapController = MapController();
  
  List<dynamic> _locationResults = [];
  bool _isLoading = false;
  bool _showMap = false; 
  LatLng _currentCenter = const LatLng(11.2588, 75.7804); 
  String _preciseAddress = "";
  Timer? _debounce;
  Map<String, dynamic>? _selectedData;

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      if(mounted) setState(() { _locationResults = []; _isLoading = false; });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=in');
      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});
      if (response.statusCode == 200 && mounted) {
        setState(() { _locationResults = json.decode(response.body); _isLoading = false; });
      }
    } catch (_) { if(mounted) setState(() => _isLoading = false); }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _selectLocation(LatLng(position.latitude, position.longitude), "Current Location");
  }

  void _selectLocation(LatLng point, String displayName) {
    setState(() {
      _currentCenter = point;
      _controller.text = displayName; 
      _showMap = true; 
      _locationResults = []; 
      
      _selectedData = {
        'name': displayName.split(',')[0],
        'lat': point.latitude,
        'lng': point.longitude,
      };
      FocusScope.of(context).unfocus();
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _mapController.move(point, 15.0);
      _getAddressFromCoords(point);
    });
  }

  Future<void> _getAddressFromCoords(LatLng point) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18');
      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String name = data['display_name'].split(',').take(2).join(',').trim();
        if(mounted) {
          setState(() {
            _preciseAddress = name;
            _controller.text = name;
            _selectedData = {
              'name': name,
              'lat': point.latitude,
              'lng': point.longitude,
            };
          });
        }
      }
    } catch (_) {}
  }

  void _confirmSelection() {
    if (_selectedData != null) {
      widget.onLocationSelected(_selectedData!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_showMap)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter, 
              initialZoom: 15.0,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 800), () {
                    _getAddressFromCoords(_mapController.camera.center);
                  });
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
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 10),
              color: _showMap ? Colors.transparent : Colors.white,
              child: TextField(
                controller: _controller,
                onChanged: (val) {
                  if (_showMap) setState(() => _showMap = false);
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () => _searchLocation(val));
                },
                decoration: InputDecoration(
                  hintText: "Enter Destination",
                  prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.red),
                  filled: true, fillColor: _showMap ? Colors.white : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: _showMap ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _controller.clear(); _showMap = false; })) : null
                ),
              ),
            ),
            if (!_showMap)
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: ListView.separated(
                    itemCount: _locationResults.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = _locationResults[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.grey),
                        title: Text(place['display_name'].split(',')[0]),
                        onTap: () => _selectLocation(LatLng(double.parse(place['lat']), double.parse(place['lon'])), place['display_name']),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),

        if (_showMap)
          const Center(child: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.location_on, size: 50, color: Colors.red))),

        if (_showMap)
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _confirmSelection,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("CONFIRM DESTINATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }
}
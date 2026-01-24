import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart'; // Map Widget
import 'package:latlong2/latlong.dart';      // Coordinates

class RideStepDestination extends StatefulWidget {
  final Function(String) onLocationSelected;

  const RideStepDestination({super.key, required this.onLocationSelected});

  @override
  State<RideStepDestination> createState() => _RideStepDestinationState();
}

class _RideStepDestinationState extends State<RideStepDestination> {
  final TextEditingController _controller = TextEditingController();
  final MapController _mapController = MapController();
  
  // State
  List<dynamic> _locationResults = [];
  bool _isLoading = false;
  bool _showMap = false; // Toggles between Search List and Map View
  LatLng _currentCenter = const LatLng(11.2588, 75.7804); // Default: Kozhikode
  String _preciseAddress = "";
  Timer? _debounce;

  // --- 1. SEARCH API ---
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      if(mounted) setState(() { _locationResults = []; _isLoading = false; });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=in');

      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});

      if (response.statusCode == 200) {
        if(mounted) {
          setState(() {
            _locationResults = json.decode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. GPS LOCATION ---
  Future<void> _getCurrentLocation() async {
    // 1. Check Permissions (Simplified for brevity)
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    // 2. Get Position
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    // 3. Move Map
    _selectLocation(LatLng(position.latitude, position.longitude), "Current Location");
  }

  // --- 3. SELECT A SUGGESTION ---
  void _selectLocation(LatLng point, String displayName) {
    setState(() {
      _currentCenter = point;
      _controller.text = displayName; // Temporary text
      _showMap = true; // Show the map
      _locationResults = []; // Clear list
      FocusScope.of(context).unfocus(); // Hide keyboard
    });
    
    // Slight delay to allow map to render before moving
    Future.delayed(const Duration(milliseconds: 100), () {
      _mapController.move(point, 15.0); // Zoom level 15
      _getAddressFromCoords(point); // Fetch precise address of center
    });
  }

  // --- 4. REVERSE GEOCODE (Get address when map moves) ---
  Future<void> _getAddressFromCoords(LatLng point) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1');

      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String name = data['display_name'];
        
        // Cleanup Address
        List<String> parts = name.split(',');
        String simplified = parts.take(2).join(',').trim();

        if(mounted) {
          setState(() {
            _preciseAddress = simplified;
            _controller.text = simplified;
          });
        }
      }
    } catch (e) {
      print("Geocoding error: $e");
    }
  }

  // --- 5. ON DRAG END (When user stops moving map) ---
  void _onMapInteractionEnd(MapEvent event) {
    // Determine the center of the map and fetch address
    // We use a small debounce so we don't spam the API while dragging
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _getAddressFromCoords(_mapController.camera.center);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- LAYER A: THE MAP (Visible only when _showMap is true) ---
        if (_showMap)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter, // Starting point
              initialZoom: 15.0,
              onMapEvent: (event) {
                // If user stops dragging/zooming, fetch new address
                if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
                  _onMapInteractionEnd(event);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.linkride',
              ),
            ],
          ),

        // --- LAYER B: SEARCH INTERFACE ---
        Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 10),
              color: _showMap ? Colors.transparent : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Only show if map is hidden to save space)
                  if (!_showMap) ...[
                    const Text("Going to...", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
                    const SizedBox(height: 20),
                  ],

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _showMap ? [const BoxShadow(color: Colors.black12, blurRadius: 10)] : [],
                    ),
                    child: TextField(
                      controller: _controller,
                      onChanged: (val) {
                        if (_showMap) setState(() => _showMap = false); // Go back to list if typing
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(const Duration(milliseconds: 500), () => _searchLocation(val));
                      },
                      decoration: InputDecoration(
                        hintText: "Enter Destination",
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.red),
                        suffixIcon: _isLoading 
                          ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                          : (_controller.text.isNotEmpty 
                              ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                                  _controller.clear();
                                  setState(() { _locationResults = []; _showMap = false; });
                                })
                              : null),
                        filled: true,
                        fillColor: _showMap ? Colors.white : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Suggestions List (Only visible if NOT showing map)
            if (!_showMap)
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Current Location Button
                      InkWell(
                        onTap: _getCurrentLocation,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          child: Row(
                            children: [
                              Icon(Icons.my_location, color: Color(0xFF11A860)),
                              SizedBox(width: 15),
                              Text("Use current location", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF11A860))),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      // Results
                      Expanded(
                        child: ListView.separated(
                          itemCount: _locationResults.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final place = _locationResults[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.grey),
                              title: Text(place['display_name'].split(',')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(place['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                double lat = double.parse(place['lat']);
                                double lon = double.parse(place['lon']);
                                _selectLocation(LatLng(lat, lon), place['display_name']);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // --- LAYER C: CENTER PIN (Only when Map is showing) ---
        if (_showMap)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40), // Offset slightly up so tip is at center
              child: Icon(Icons.location_on, size: 50, color: Colors.red),
            ),
          ),

        // --- LAYER D: CONFIRM BUTTON (Only when Map is showing) ---
        if (_showMap)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // "Drag map" hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Text("Move map to adjust pin", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(height: 15),
                // Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => widget.onLocationSelected(_preciseAddress.isEmpty ? _controller.text : _preciseAddress),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF11A860),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("CONFIRM DESTINATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
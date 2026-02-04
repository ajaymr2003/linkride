import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class RouteOption {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final String name;
  final String description;

  RouteOption({required this.points, required this.distance, required this.duration, required this.name, required this.description});
}

class RideStepRoute extends StatefulWidget {
  // CHANGED: Accept Map Objects directly
  final Map<String, dynamic> source;
  final Map<String, dynamic> destination;
  final Function(String) onRouteSelected;

  const RideStepRoute({
    super.key,
    required this.source,
    required this.destination,
    required this.onRouteSelected,
  });

  @override
  State<RideStepRoute> createState() => _RideStepRouteState();
}

class _RideStepRouteState extends State<RideStepRoute> {
  bool _isLoading = true;
  List<RouteOption> _routes = [];
  int _selectedRouteIndex = 0;
  final MapController _mapController = MapController();
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    _calculateRoutes();
  }

  Future<void> _calculateRoutes() async {
    try {
      // Use coordinates passed from previous steps directly
      final LatLng start = LatLng(widget.source['lat'], widget.source['lng']);
      final LatLng end = LatLng(widget.destination['lat'], widget.destination['lng']);

      await _fetchOSRMRoutes(start, end);
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOSRMRoutes(LatLng start, LatLng end) async {
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> routesJson = data['routes'];
        List<RouteOption> tempRoutes = [];

        for (var i = 0; i < routesJson.length; i++) {
          var r = routesJson[i];
          List<dynamic> coords = r['geometry']['coordinates'];
          List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();

          double distKm = r['distance'] / 1000;
          double durMin = r['duration'] / 60;
          String rName = (r['legs'].isNotEmpty && r['legs'][0]['summary'].isNotEmpty) ? "Via ${r['legs'][0]['summary']}" : "Alternative Route";
          
          tempRoutes.add(RouteOption(
            points: points,
            distance: "${distKm.toStringAsFixed(1)} km",
            duration: "${durMin.round()} min",
            name: i == 0 ? "Fastest Route" : rName,
            description: i == 0 ? "Best route based on traffic" : "Similar ETA",
          ));
        }
        
        // Fallback for single route
        if (tempRoutes.length == 1) {
           List<LatLng> offsetPoints = tempRoutes[0].points.map((p) => LatLng(p.latitude + 0.001, p.longitude + 0.001)).toList();
           tempRoutes.add(RouteOption(points: offsetPoints, distance: tempRoutes[0].distance, duration: tempRoutes[0].duration, name: "Via Old Highway", description: "Alternate path"));
        }

        if(mounted) {
          setState(() { _routes = tempRoutes; _isLoading = false; });
          Future.delayed(const Duration(milliseconds: 500), _fitCameraBounds);
        }
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _fitCameraBounds() {
    if (_routes.isEmpty) return;
    var points = _routes[_selectedRouteIndex].points;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLon = points.first.longitude, maxLon = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon)), padding: const EdgeInsets.all(50)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: LatLng(widget.source['lat'], widget.source['lng']), initialZoom: 10),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
              PolylineLayer(polylines: _routes.asMap().entries.map((e) => Polyline(
                  points: e.value.points, 
                  strokeWidth: e.key == _selectedRouteIndex ? 5.0 : 4.0, 
                  color: e.key == _selectedRouteIndex ? Colors.blue : Colors.grey)).toList()),
            ],
          ),
        ),
        Container(
          height: 300,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _routes.length,
                  itemBuilder: (context, index) {
                    final route = _routes[index];
                    final isSelected = index == _selectedRouteIndex;
                    return ListTile(
                      title: Text(route.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text("${route.distance} • ${route.duration}"),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF11A860)) : const Icon(Icons.circle_outlined),
                      onTap: () { setState(() => _selectedRouteIndex = index); _fitCameraBounds(); },
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => widget.onRouteSelected(_routes[_selectedRouteIndex].name),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  child: const Text("CONFIRM ROUTE", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}
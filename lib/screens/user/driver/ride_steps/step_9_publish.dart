import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RideStepPublish extends StatefulWidget {
  // CHANGED: Accepting Maps
  final Map<String, dynamic> source;
  final Map<String, dynamic> destination;
  
  final String route;
  final DateTime? date;
  final TimeOfDay? time;
  final Map<String, dynamic>? vehicle;
  final int seats;
  final double price;

  const RideStepPublish({
    super.key,
    required this.source,
    required this.destination,
    required this.route,
    required this.date,
    required this.time,
    required this.vehicle,
    required this.seats,
    required this.price,
  });

  @override
  State<RideStepPublish> createState() => _RideStepPublishState();
}

class _RideStepPublishState extends State<RideStepPublish> {
  bool _isPublishing = false;

  Future<void> _publishRide() async {
    setState(() => _isPublishing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;

      final dt = DateTime(
        widget.date!.year, widget.date!.month, widget.date!.day,
        widget.time!.hour, widget.time!.minute,
      );

      await FirebaseFirestore.instance.collection('rides').add({
        'driver_uid': user!.uid,
        
        // CHANGED: Storing Object with Name + Coordinates
        'source': {
          'name': widget.source['name'],
          'lat': widget.source['lat'],
          'lng': widget.source['lng'],
          // Optional: Store as GeoPoint for easier querying
          'location': GeoPoint(widget.source['lat'], widget.source['lng']),
        },
        'destination': {
          'name': widget.destination['name'],
          'lat': widget.destination['lat'],
          'lng': widget.destination['lng'],
          'location': GeoPoint(widget.destination['lat'], widget.destination['lng']),
        },

        'route': widget.route,
        'departure_time': Timestamp.fromDate(dt),
        'vehicle': widget.vehicle,
        'total_seats': widget.seats,
        'available_seats': widget.seats,
        'price_per_seat': widget.price,
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF11A860), size: 60),
                const SizedBox(height: 20),
                const Text("Ride Published!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860)),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close Setup Screen
                  },
                  child: const Text("DONE", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Review your ride", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                _row(Icons.my_location, widget.source['name']), // Display just the name
                const Padding(padding: EdgeInsets.only(left: 12), child: SizedBox(height: 20, child: VerticalDivider())),
                _row(Icons.location_on, widget.destination['name']),
                const Divider(height: 30),
                _row(Icons.calendar_today, "${DateFormat('EEE, dd MMM').format(widget.date!)} at ${widget.time!.format(context)}"),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${widget.seats} Seats", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("₹${widget.price.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF11A860))),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860)),
              onPressed: _isPublishing ? null : _publishRide,
              child: _isPublishing 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("PUBLISH RIDE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF11A860), size: 20),
        const SizedBox(width: 15),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
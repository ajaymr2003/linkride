import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'step_1_location.dart';
import 'step_2_destination.dart';

class EditRidePage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const EditRidePage({super.key, required this.docId, required this.initialData});

  @override
  State<EditRidePage> createState() => _EditRidePageState();
}

class _EditRidePageState extends State<EditRidePage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _sourceController;
  late TextEditingController _destController;
  late TextEditingController _priceController;
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late int _seats;
  Map<String, dynamic>? _selectedVehicle;
  bool _isLoading = false;

  Map<String, dynamic>? _newSourceObj;
  Map<String, dynamic>? _newDestObj;

  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    if (data['source'] is Map) {
      _sourceController = TextEditingController(text: data['source']['name']);
      _newSourceObj = data['source'];
    } else {
      _sourceController = TextEditingController(text: data['source']);
    }

    if (data['destination'] is Map) {
      _destController = TextEditingController(text: data['destination']['name']);
      _newDestObj = data['destination'];
    } else {
      _destController = TextEditingController(text: data['destination']);
    }

    _priceController = TextEditingController(text: data['price_per_seat'].toString());
    
    DateTime dt = (data['departure_time'] as Timestamp).toDate();
    _selectedDate = dt;
    _selectedTime = TimeOfDay.fromDateTime(dt);
    _seats = data['available_seats'] ?? 1;
    _selectedVehicle = data['vehicle'];
  }

  void _openSourcePicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
          body: RideStepLocation(
            title: "Edit Pickup",
            hint: "Search new location",
            icon: Icons.my_location,
            onLocationSelected: (locationMap) {
              Navigator.pop(context, locationMap);
            },
          ),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _sourceController.text = result['name'];
        _newSourceObj = result;
      });
    }
  }

  void _openDestinationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
          body: RideStepDestination(
            onLocationSelected: (locationMap) {
              Navigator.pop(context, locationMap);
            },
          ),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _destController.text = result['name'];
        _newDestObj = result;
      });
    }
  }

  Future<void> _updateRide() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final finalDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      var finalSource = _newSourceObj ?? widget.initialData['source'];
      var finalDest = _newDestObj ?? widget.initialData['destination'];

      await FirebaseFirestore.instance.collection('rides').doc(widget.docId).update({
        'source': finalSource,
        'destination': finalDest,
        'departure_time': Timestamp.fromDate(finalDateTime),
        'available_seats': _seats,
        'price_per_seat': double.parse(_priceController.text),
        'vehicle': _selectedVehicle,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ride updated successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Ride", style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.black, backgroundColor: Colors.white, elevation: 0
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- NEW: REQUESTS BUTTON ---
              _buildRequestSummary(),
              const SizedBox(height: 20),

              _buildSectionTitle("ROUTE"),
              _readOnlyInputField("From", _sourceController, Icons.circle_outlined, _openSourcePicker),
              const SizedBox(height: 15),
              _readOnlyInputField("To", _destController, Icons.location_on, _openDestinationPicker),
              
              const SizedBox(height: 30),
              _buildSectionTitle("DATE & TIME"),
              Row(
                children: [
                  Expanded(child: _pickerTile(DateFormat('dd MMM, yyyy').format(_selectedDate), Icons.calendar_today, () async {
                    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) setState(() => _selectedDate = d);
                  })),
                  const SizedBox(width: 15),
                  Expanded(child: _pickerTile(_selectedTime.format(context), Icons.access_time, () async {
                    final t = await showTimePicker(context: context, initialTime: _selectedTime);
                    if (t != null) setState(() => _selectedTime = t);
                  })),
                ],
              ),

              const SizedBox(height: 30),
              _buildSectionTitle("VEHICLE"),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).collection('vehicles').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LinearProgressIndicator();
                  List<Map<String, dynamic>> vehicles = snap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
                  Map<String, dynamic>? currentValue;
                  if (_selectedVehicle != null) {
                    try { currentValue = vehicles.firstWhere((v) => v['plate'] == _selectedVehicle?['plate']); } catch (e) { currentValue = null; }
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true, value: currentValue, hint: const Text("Select Vehicle"),
                        items: vehicles.map((v) => DropdownMenuItem(value: v, child: Text("${v['brand']} ${v['model']} (${v['plate']})"))).toList(),
                        onChanged: (val) => setState(() => _selectedVehicle = val),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
              _buildSectionTitle("PASSENGERS & PRICE"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Available Seats", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(onPressed: () => setState(() => _seats > 1 ? _seats-- : null), icon: const Icon(Icons.remove_circle_outline)),
                      Text("$_seats", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => setState(() => _seats < 8 ? _seats++ : null), icon: Icon(Icons.add_circle_outline, color: primaryGreen)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 15),
              _editableInputField("Price per seat (₹)", _priceController, Icons.payments_outlined, isNumber: true),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: _isLoading ? null : _updateRide,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget to show number of pending requests and button
  Widget _buildRequestSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('ride_id', isEqualTo: widget.docId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.orange.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: count > 0 ? Colors.orange.shade200 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.people_outline, color: count > 0 ? Colors.orange : Colors.grey),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$count Pending Requests", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text("Review passengers for this ride", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RideBookingsScreen(rideId: widget.docId)),
                ),
                child: Text("VIEW", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _readOnlyInputField(String label, TextEditingController controller, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: IgnorePointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label, prefixIcon: Icon(icon, color: primaryGreen),
            filled: true, fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  Widget _editableInputField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: primaryGreen),
        filled: true, fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 5), child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)));

  Widget _pickerTile(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: Row(children: [Icon(icon, size: 18, color: primaryGreen), const SizedBox(width: 10), Text(text, style: const TextStyle(fontWeight: FontWeight.bold))]),
      ),
    );
  }
}

// --- NEW PAGE: RideBookingsScreen ---
class RideBookingsScreen extends StatelessWidget {
  final String rideId;
  const RideBookingsScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ride Requests")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('ride_id', isEqualTo: rideId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No requests for this ride."));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              var bookingId = snapshot.data!.docs[index].id;
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(data['passenger_uid']).get(),
                builder: (context, userSnap) {
                  String name = userSnap.hasData ? (userSnap.data!['name'] ?? "User") : "Loading...";
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text("Status: ${data['status'].toString().toUpperCase()}"),
                      trailing: data['status'] == 'pending' 
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                onPressed: () => _handleStatus(context, bookingId, rideId, 'accepted'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _handleStatus(context, bookingId, rideId, 'rejected'),
                              ),
                            ],
                          )
                        : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleStatus(BuildContext context, String bookingId, String rId, String status) async {
    try {
      if (status == 'accepted') {
        // Run a transaction to ensure we don't overbook
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(rId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);
          
          int available = rideSnap['available_seats'] ?? 0;
          if (available < 1) throw "No seats available!";
          
          transaction.update(rideRef, {'available_seats': available - 1});
          transaction.update(FirebaseFirestore.instance.collection('bookings').doc(bookingId), {'status': 'accepted'});
        });
      } else {
        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({'status': 'rejected'});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
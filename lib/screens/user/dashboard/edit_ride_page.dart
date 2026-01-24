import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Import your existing search steps
import '../driver/ride_steps/step_1_location.dart';
import '../driver/ride_steps/step_2_destination.dart';

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

  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _sourceController = TextEditingController(text: data['source']);
    _destController = TextEditingController(text: data['destination']);
    _priceController = TextEditingController(text: data['price_per_seat'].toString());
    
    DateTime dt = (data['departure_time'] as Timestamp).toDate();
    _selectedDate = dt;
    _selectedTime = TimeOfDay.fromDateTime(dt);
    _seats = data['available_seats'] ?? 1;
    _selectedVehicle = data['vehicle'];
  }

  // --- NAVIGATION TO SEARCH STEP 1 (SOURCE) ---
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
            onLocationSelected: (location) {
              Navigator.pop(context, location); // Return the string
            },
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() => _sourceController.text = result);
    }
  }

  // --- NAVIGATION TO SEARCH STEP 2 (DESTINATION) ---
  void _openDestinationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
          body: RideStepDestination(
            onLocationSelected: (location) {
              Navigator.pop(context, location); // Return the string
            },
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() => _destController.text = result);
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

      await FirebaseFirestore.instance.collection('rides').doc(widget.docId).update({
        'source': _sourceController.text.trim(),
        'destination': _destController.text.trim(),
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
              _buildSectionTitle("ROUTE"),
              
              // FROM FIELD (Clickable)
              _readOnlyInputField("From", _sourceController, Icons.circle_outlined, _openSourcePicker),
              const SizedBox(height: 15),
              
              // TO FIELD (Clickable)
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

  // Helper for From/To fields that open the searcher
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

  // Standard editable field for Price
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
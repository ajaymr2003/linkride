import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EditRidePage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const EditRidePage({
    super.key,
    required this.docId,
    required this.initialData,
  });

  @override
  State<EditRidePage> createState() => _EditRidePageState();
}

class _EditRidePageState extends State<EditRidePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _sourceController;
  late TextEditingController _destController;
  late TextEditingController _priceController;

  // State Variables
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

    // Initialize text fields
    _sourceController = TextEditingController(text: data['source']);
    _destController = TextEditingController(text: data['destination']);
    _priceController = TextEditingController(
      text: data['price_per_seat'].toString(),
    );

    // Initialize Date and Time from Firestore Timestamp
    DateTime dt = (data['departure_time'] as Timestamp).toDate();
    _selectedDate = dt;
    _selectedTime = TimeOfDay.fromDateTime(dt);

    // Initialize other details
    _seats = data['available_seats'] ?? 1;
    _selectedVehicle = data['vehicle'];
  }

  Future<void> _updateRide() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Combine selected date and time
      final finalDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.docId)
          .update({
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
          const SnackBar(
            content: Text("Ride updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Update failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Edit Ride Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("ROUTE"),
              _inputField("From", _sourceController, Icons.circle_outlined),
              const SizedBox(height: 15),
              _inputField("To", _destController, Icons.location_on),

              const SizedBox(height: 30),
              _buildSectionTitle("DATE & TIME"),
              Row(
                children: [
                  Expanded(
                    child: _pickerTile(
                      DateFormat('dd MMM, yyyy').format(_selectedDate),
                      Icons.calendar_today,
                      () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (d != null) setState(() => _selectedDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _pickerTile(
                      _selectedTime.format(context),
                      Icons.access_time,
                      () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (t != null) setState(() => _selectedTime = t);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              _buildSectionTitle("VEHICLE"),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('vehicles')
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LinearProgressIndicator();

                  List<Map<String, dynamic>> vehicles = snap.data!.docs
                      .map((d) => d.data() as Map<String, dynamic>)
                      .toList();

                  // FIX: Find the correct object reference using the 'plate' string
                  Map<String, dynamic>? currentValue;
                  if (_selectedVehicle != null) {
                    try {
                      currentValue = vehicles.firstWhere(
                        (v) => v['plate'] == _selectedVehicle?['plate'],
                      );
                    } catch (e) {
                      currentValue = null;
                    }
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        value: currentValue,
                        hint: const Text("Select Vehicle"),
                        items: vehicles.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text(
                              "${v['brand']} ${v['model']} (${v['plate']})",
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedVehicle = val),
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
                  const Text(
                    "Available Seats",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            setState(() => _seats > 1 ? _seats-- : null),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "$_seats",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _seats < 8 ? _seats++ : null),
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _inputField(
                "Price per seat (₹)",
                _priceController,
                Icons.payments_outlined,
                isNumber: true,
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _isLoading ? null : _updateRide,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SAVE CHANGES",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 5),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _inputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: primaryGreen),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _pickerTile(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primaryGreen),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}

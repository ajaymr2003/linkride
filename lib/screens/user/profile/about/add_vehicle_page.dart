import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  
  String _selectedType = "Hatchback";
  final List<String> _types = ["Hatchback", "Sedan", "SUV", "Convertible", "Minivan", "Other"];
  
  bool _isLoading = false;
  final Color primaryGreen = const Color(0xFF11A860);

  Future<void> _addVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      
      // Add to a sub-collection named 'vehicles' for the user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('vehicles')
          .add({
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'color': _colorController.text.trim(),
        'plate': _plateController.text.trim().toUpperCase(),
        'type': _selectedType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add vehicle")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Add Vehicle"), elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Vehicle Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              _field("Brand (e.g. Maruti)", _brandController),
              const SizedBox(height: 15),
              _field("Model (e.g. Swift)", _modelController),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _field("Color", _colorController)),
                  const SizedBox(width: 15),
                  Expanded(child: _dropdown()),
                ],
              ),
              const SizedBox(height: 15),
              _field("License Plate Number", _plateController),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  onPressed: _isLoading ? null : _addVehicle,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("ADD VEHICLE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );
  }

  Widget _dropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      decoration: InputDecoration(labelText: "Type", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) => setState(() => _selectedType = v!),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'step_brand.dart';
import 'step_model.dart'; // Updated
import 'step_color.dart';
import 'step_plate.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final PageController _pageController = PageController();
  final Color primaryGreen = const Color(0xFF11A860);

  String _selectedBrand = "";
  String _selectedModel = ""; // Changed name from enteredModel to selectedModel
  String _selectedColor = "";
  
  int _currentStep = 0;
  bool _isSaving = false;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep++);
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _saveVehicle(String plate) async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('vehicles').add({
        'brand': _selectedBrand,
        'model': _selectedModel,
        'color': _selectedColor,
        'plate': plate.toUpperCase().replaceAll(" ", ""),
        'type': 'Passenger', 
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vehicle added!"), backgroundColor: primaryGreen));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _prevPage();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: _prevPage),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) => _stepIndicator(index)),
          ),
        ),
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StepBrand(
                onBrandSelected: (brand) {
                  setState(() => _selectedBrand = brand);
                  _nextPage();
                },
              ),
              StepModel(
                brandName: _selectedBrand,
                onModelEntered: (model) {
                  setState(() => _selectedModel = model);
                  _nextPage();
                },
              ),
              StepColor(
                onColorSelected: (color) {
                  setState(() => _selectedColor = color);
                  _nextPage();
                },
              ),
              StepPlate(
                brand: _selectedBrand,
                model: _selectedModel,
                color: _selectedColor,
                isSaving: _isSaving,
                onSave: _saveVehicle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator(int stepIndex) {
    bool isActive = _currentStep >= stepIndex;
    return Row(
      children: [
        Container(
          width: 25, height: 25,
          decoration: BoxDecoration(color: isActive ? primaryGreen : Colors.grey[200], shape: BoxShape.circle),
          child: Center(child: Text("${stepIndex + 1}", style: TextStyle(fontSize: 12, color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))),
        ),
        if (stepIndex < 3) Container(width: 40, height: 2, color: Colors.grey[200]),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StepDob extends StatefulWidget {
  const StepDob({super.key});

  @override
  State<StepDob> createState() => _StepDobState();
}

class _StepDobState extends State<StepDob> {
  DateTime? _date;
  bool _isLoading = false;
  final Color primaryGreen = const Color(0xFF11A860);

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(now.year - 100),
      lastDate: eighteenYearsAgo, // STRICT LOCK: Only 18+ allowed
      helpText: "SELECT YOUR DATE OF BIRTH",
    );

    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _saveToDb() async {
    if (_date == null) return;
    setState(() => _isLoading = true);

    try {
      final String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'dob': DateFormat('yyyy-MM-dd').format(_date!),
      });
      if (mounted) Navigator.pop(context);
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
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Date of Birth", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
            const SizedBox(height: 10),
            const Text("Drivers must be at least 18 years old.", style: TextStyle(color: Colors.grey)),
            const Spacer(),
            Center(
              child: InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15), border: Border.all(color: _date != null ? primaryGreen : Colors.grey.shade300)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cake_outlined, color: _date != null ? primaryGreen : Colors.grey),
                      const SizedBox(width: 15),
                      Text(_date == null ? "Select Birth Date" : DateFormat('dd MMMM, yyyy').format(_date!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                onPressed: _date == null || _isLoading ? null : _saveToDb,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
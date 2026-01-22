import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RegistrationSuccessPage extends StatelessWidget {
  final String applicantName, applicationNumber, contactNumber;
  const RegistrationSuccessPage({super.key, required this.applicantName, required this.applicationNumber, required this.contactNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0F5),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Color(0xFFF0F4F8), borderRadius: BorderRadius.vertical(top: Radius.circular(12))), child: Row(children: [const Expanded(child: Text("കോഴിക്കോട് - മുക്കം മുനിസിപ്പാലിറ്റി", style: TextStyle(color: Color(0xFF00338D), fontWeight: FontWeight.bold))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
              Padding(padding: const EdgeInsets.all(25), child: Row(children: [Container(height: 100, width: 80, decoration: BoxDecoration(color: Colors.blue[50]), child: const Icon(Icons.description, size: 50, color: Colors.blue)), const SizedBox(width: 20), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Acknowledgment", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00338D))), _row("Application Number", applicationNumber), _row("Applicant Name", applicantName), _row("Contact Number", contactNumber)]))])),
              Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Color(0xFFF0F4F8), borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${DateFormat('h:mm a').format(DateTime.now())}  ${DateFormat('dd-MM-yyyy').format(DateTime.now())}"), OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.pink)))]))
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 10)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00338D)))]));
}
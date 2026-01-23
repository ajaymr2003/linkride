  import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StepPlate extends StatefulWidget {
  final String brand;
  final String model;
  final String color;
  final bool isSaving;
  final Function(String) onSave;

  const StepPlate({
    super.key,
    required this.brand,
    required this.model,
    required this.color,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<StepPlate> createState() => _StepPlateState();
}

class _StepPlateState extends State<StepPlate> {
  final TextEditingController _controller = TextEditingController();
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("License Plate Number", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
          const SizedBox(height: 10),
          Text("For your ${widget.color} ${widget.brand} ${widget.model}", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => setState((){}), // rebuild to enable button
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
            style: const TextStyle(fontSize: 24, letterSpacing: 2, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "KL10AB1234",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            ),
          ),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              onPressed: (_controller.text.isNotEmpty && !widget.isSaving) 
                  ? () => widget.onSave(_controller.text) 
                  : null,
              child: widget.isSaving 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("SAVE VEHICLE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

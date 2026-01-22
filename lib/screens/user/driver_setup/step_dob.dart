import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StepDob extends StatefulWidget {
  final Function(String) onDateSelected;
  const StepDob({super.key, required this.onDateSelected});

  @override
  State<StepDob> createState() => _StepDobState();
}

class _StepDobState extends State<StepDob> {
  DateTime? _date;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    bool is18 = _date != null && (DateTime.now().year - _date!.year >= 18);

    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        children: [
          const Text("Date of Birth", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Spacer(),
          ListTile(
            tileColor: Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            leading: const Icon(Icons.calendar_month),
            title: Text(_date == null ? "Select Birth Date" : DateFormat('dd-MM-yyyy').format(_date!)),
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now());
              if (picked != null) setState(() => _date = picked);
            },
          ),
          if (_date != null && !is18) const Text("\nMust be 18+ to drive", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: is18 ? () => widget.onDateSelected(DateFormat('yyyy-MM-dd').format(_date!)) : null,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              child: const Text("CONTINUE", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
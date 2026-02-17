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

  // --- AGE CALCULATION LOGIC ---
  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    
    // Calculate the latest date a user can be born to be 18 today
    final DateTime eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      // Default focus on the 18-year mark
      initialDate: eighteenYearsAgo, 
      // Allow users up to 100 years old
      firstDate: DateTime(now.year - 100), 
      // STRICT LOCK: Prevents picking any date after 18 years ago
      lastDate: eighteenYearsAgo, 
      helpText: "SELECT YOUR DATE OF BIRTH",
      fieldLabelText: "Birth Date",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryGreen, 
              onPrimary: Colors.white, 
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Date of Birth", 
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))
          ),
          const SizedBox(height: 10),
          const Text(
            "Drivers must be at least 18 years old to provide rides on LinkRide.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          
          const Spacer(),
          
          Center(
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _date != null ? primaryGreen : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cake_outlined, color: _date != null ? primaryGreen : Colors.grey),
                    const SizedBox(width: 15),
                    Text(
                      _date == null ? "Select Birth Date" : DateFormat('dd MMMM, yyyy').format(_date!),
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: _date != null ? Colors.black : Colors.grey
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _date != null 
                  ? () => widget.onDateSelected(DateFormat('yyyy-MM-dd').format(_date!)) 
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "CONTINUE", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
              ),
            ),
          ),
        ],
      ),
    );
  }
}
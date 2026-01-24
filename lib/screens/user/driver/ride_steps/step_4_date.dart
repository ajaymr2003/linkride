import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideStepDate extends StatefulWidget {
  final Function(DateTime) onDateSelected;
  const RideStepDate({super.key, required this.onDateSelected});

  @override
  State<RideStepDate> createState() => _RideStepDateState();
}

class _RideStepDateState extends State<RideStepDate> {
  DateTime _selectedDate = DateTime.now();
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    // Format: "Mon, 25 October"
    String dateText = DateFormat('EEE, dd MMMM yyyy').format(_selectedDate);
    
    // Check if it's today
    final now = DateTime.now();
    if (_selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day) {
      dateText = "Today, ${DateFormat('dd MMMM').format(_selectedDate)}";
    }

    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "When are you going?", 
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))
          ),
          
          const SizedBox(height: 20),

          // --- TOP DISPLAY: SELECTED DATE ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1), // Light green background
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: primaryGreen, size: 28),
                const SizedBox(width: 15),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: primaryGreen
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          
          // --- CALENDAR ---
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)), // Allow booking 3 months ahead
                onDateChanged: (date) {
                  setState(() => _selectedDate = date);
                },
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          // --- CONFIRM BUTTON ---
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => widget.onDateSelected(_selectedDate),
              child: const Text("CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
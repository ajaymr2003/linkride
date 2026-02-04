import 'package:flutter/material.dart';


class PassengerStepDetails extends StatefulWidget {
  final DateTime initialDate;
  final int initialPassengers;

  const PassengerStepDetails({
    super.key, 
    required this.initialDate, 
    required this.initialPassengers
  });

  @override
  State<PassengerStepDetails> createState() => _PassengerStepDetailsState();
}

class _PassengerStepDetailsState extends State<PassengerStepDetails> {
  late DateTime _selectedDate;
  late int _passengers;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _passengers = widget.initialPassengers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black), 
          onPressed: () => Navigator.pop(context)
        ),
        title: const Text("Ride Options", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- DATE SECTION ---
            const Text("When are you going?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(15)
              ),
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                onDateChanged: (val) => setState(() => _selectedDate = val),
              ),
            ),

            const SizedBox(height: 30),

            // --- PASSENGER SECTION ---
            const Text("Passengers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(15)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Number of seats", style: TextStyle(fontSize: 16)),
                  Row(
                    children: [
                      _circleBtn(Icons.remove, () {
                        if (_passengers > 1) setState(() => _passengers--);
                      }),
                      SizedBox(
                        width: 40, 
                        child: Center(child: Text("$_passengers", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))
                      ),
                      _circleBtn(Icons.add, () {
                        if (_passengers < 8) setState(() => _passengers++);
                      }),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // --- CONFIRM BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'date': _selectedDate,
                    'passengers': _passengers
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primaryGreen),
        ),
        child: Icon(icon, color: primaryGreen, size: 20),
      ),
    );
  }
}
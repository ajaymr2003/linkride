import 'package:flutter/material.dart';

class RideStepPassengers extends StatefulWidget {
  final int initialCount;
  final Function(int) onCountSelected;
  const RideStepPassengers({
    super.key,
    required this.initialCount,
    required this.onCountSelected,
  });

  @override
  State<RideStepPassengers> createState() => _RideStepPassengersState();
}

class _RideStepPassengersState extends State<RideStepPassengers> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    // Ensure we don't start above the new limit if editing an old ride
    if (_count > 3) _count = 3;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total passengers",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B5145),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "How many seats are available?",
            style: TextStyle(color: Colors.grey),
          ),
          
          // Using Expanded to push the counter to the center vertically
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // DECREMENT BUTTON
                _circleBtn(
                  Icons.remove, 
                  () {
                    if (_count > 1) setState(() => _count--);
                  },
                  isEnabled: _count > 1
                ),
                
                const SizedBox(width: 40),

                // NUMBER DISPLAY
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      "$_count",
                      style: const TextStyle(
                        fontSize: 80, // Made slightly bigger for visibility
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF11A860),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 40),

                // INCREMENT BUTTON
                _circleBtn(
                  Icons.add, 
                  () {
                    // CHANGED LIMIT TO 3 HERE
                    if (_count < 3) setState(() => _count++);
                  },
                  isEnabled: _count < 3
                ),
              ],
            ),
          ),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF11A860),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => widget.onCountSelected(_count),
              child: const Text(
                "CONTINUE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool isEnabled = true}) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(50),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.3, // Dim button if disabled
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF11A860), width: 2),
            color: Colors.white,
          ),
          child: Icon(icon, size: 30, color: const Color(0xFF11A860)),
        ),
      ),
    );
  }
}
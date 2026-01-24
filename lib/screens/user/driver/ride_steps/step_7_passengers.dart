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
          const Text(
            "How many seats are available?",
            style: TextStyle(color: Colors.grey),
          ),
          const Spacer(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleBtn(Icons.remove, () {
                if (_count > 1) setState(() => _count--);
              }),
              Text(
                "$_count",
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF11A860),
                ),
              ),
              _circleBtn(Icons.add, () {
                if (_count < 8) setState(() => _count++);
              }),
            ],
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF11A860),
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

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF11A860), width: 2),
        ),
        child: Icon(icon, size: 30, color: const Color(0xFF11A860)),
      ),
    );
  }
}

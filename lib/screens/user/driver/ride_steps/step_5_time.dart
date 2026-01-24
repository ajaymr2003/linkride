import 'package:flutter/material.dart';

class RideStepTime extends StatefulWidget {
  final Function(TimeOfDay) onTimeSelected;
  const RideStepTime({super.key, required this.onTimeSelected});

  @override
  State<RideStepTime> createState() => _RideStepTimeState();
}

class _RideStepTimeState extends State<RideStepTime> {
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  Future<void> _pickTime() async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (newTime != null) {
      setState(() => _time = newTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "At what time?",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B5145),
            ),
          ),
          const Spacer(),

          Center(
            child: GestureDetector(
              onTap: _pickTime,
              child: Text(
                _time.format(context),
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF11A860),
                ),
              ),
            ),
          ),
          const Center(
            child: Text(
              "Tap to change time",
              style: TextStyle(color: Colors.grey),
            ),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF11A860),
              ),
              onPressed: () => widget.onTimeSelected(_time),
              child: const Text(
                "CONFIRM TIME",
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
}

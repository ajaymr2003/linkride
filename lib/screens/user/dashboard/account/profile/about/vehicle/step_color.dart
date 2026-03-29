import 'package:flutter/material.dart';

class StepColor extends StatelessWidget {
  final Function(String) onColorSelected;

  StepColor({super.key, required this.onColorSelected});

  final List<Map<String, dynamic>> _commonColors = [
    {"name": "White", "code": Colors.white, "text": Colors.black},
    {"name": "Black", "code": Colors.black, "text": Colors.white},
    {"name": "Silver", "code": Colors.grey.shade400, "text": Colors.black},
    {"name": "Grey", "code": Colors.grey.shade700, "text": Colors.white},
    {"name": "Red", "code": Colors.red.shade700, "text": Colors.white},
    {"name": "Blue", "code": Colors.blue.shade800, "text": Colors.white},
    {"name": "Brown", "code": Colors.brown, "text": Colors.white},
    {"name": "Other", "code": Colors.teal, "text": Colors.white},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text("Select Color", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: _commonColors.length,
            itemBuilder: (context, index) {
              final colorData = _commonColors[index];
              return InkWell(
                onTap: () => onColorSelected(colorData['name']),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorData['code'],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))
                    ]
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    colorData['name'],
                    style: TextStyle(
                      color: colorData['text'],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

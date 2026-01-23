import 'package:flutter/material.dart';
import 'vehicle_data.dart'; // Import the data file

class StepModel extends StatefulWidget {
  final String brandName;
  final Function(String) onModelEntered;

  const StepModel({
    super.key, 
    required this.brandName, 
    required this.onModelEntered,
  });

  @override
  State<StepModel> createState() => _StepModelState();
}

class _StepModelState extends State<StepModel> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController(); // For manual entry if needed
  
  List<String> _allModels = [];
  List<String> _filteredModels = [];
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    // Fetch models for the specific brand
    _allModels = VehicleData.getModels(widget.brandName);
    _filteredModels = _allModels;
  }

  void _filterModels(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredModels = _allModels;
      } else {
        _filteredModels = _allModels
            .where((model) => model.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If user selected "Other" or explicitly wants to type
    if (_showCustomInput || widget.brandName == "Other") {
      return _buildCustomInput();
    }

    return Column(
      children: [
        // --- Header & Search ---
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select ${widget.brandName} Model", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
              const SizedBox(height: 15),
              TextField(
                controller: _searchController,
                onChanged: _filterModels,
                decoration: InputDecoration(
                  hintText: "Search Model (e.g. Swift)",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ],
          ),
        ),

        // --- List ---
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filteredModels.length + 1, // +1 for "My model is not listed"
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              // Footer Item
              if (index == _filteredModels.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: TextButton(
                    onPressed: () => setState(() => _showCustomInput = true),
                    child: const Text("My model is not listed", style: TextStyle(color: Color(0xFF11A860), fontWeight: FontWeight.bold)),
                  ),
                );
              }

              final model = _filteredModels[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                title: Text(model, style: const TextStyle(fontSize: 16)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                onTap: () => widget.onModelEntered(model),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomInput() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Enter Model Name", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
          const SizedBox(height: 10),
          const Text("We couldn't find your model in our list. Please type it below.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          TextField(
            controller: _customModelController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: "Model Name",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 20),
          if (_showCustomInput && widget.brandName != "Other")
            TextButton(
              onPressed: () => setState(() => _showCustomInput = false),
              child: const Text("Back to list"),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860)),
              onPressed: () {
                if (_customModelController.text.trim().isNotEmpty) {
                  widget.onModelEntered(_customModelController.text.trim());
                }
              },
              child: const Text("NEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'vehicle_data.dart'; // Import the data file

class StepBrand extends StatefulWidget {
  final Function(String) onBrandSelected;
  const StepBrand({super.key, required this.onBrandSelected});

  @override
  State<StepBrand> createState() => _StepBrandState();
}

class _StepBrandState extends State<StepBrand> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _allBrands = [];
  List<String> _filteredBrands = [];

  @override
  void initState() {
    super.initState();
    _allBrands = VehicleData.getBrands();
    _filteredBrands = _allBrands;
  }

  void _filterBrands(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBrands = _allBrands;
      } else {
        _filteredBrands = _allBrands
            .where((brand) => brand.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Header & Search ---
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Brand", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
              const SizedBox(height: 15),
              TextField(
                controller: _searchController,
                onChanged: _filterBrands,
                decoration: InputDecoration(
                  hintText: "Search Brand (e.g. Toyota)",
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
          child: _filteredBrands.isEmpty 
          ? Center(child: Text("No brand found", style: TextStyle(color: Colors.grey.shade400)))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              itemCount: _filteredBrands.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final brand = _filteredBrands[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  title: Text(brand, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  onTap: () => widget.onBrandSelected(brand),
                );
              },
            ),
        ),
      ],
    );
  }
}
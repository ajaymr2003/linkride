import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RideStepPrice extends StatefulWidget {
  final double recommendedPrice;
  final Function(double) onPriceConfirmed;
  const RideStepPrice({super.key, required this.recommendedPrice, required this.onPriceConfirmed});

  @override
  State<RideStepPrice> createState() => _RideStepPriceState();
}

class _RideStepPriceState extends State<RideStepPrice> {
  late double _price;
  late TextEditingController _priceController;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    _price = widget.recommendedPrice;
    _priceController = TextEditingController(text: _price.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  // --- SYNC FUNCTION: BUTTONS TO TEXTFIELD ---
  void _updatePrice(double newPrice) {
    if (newPrice < 0) newPrice = 0;
    setState(() {
      _price = newPrice;
      _priceController.text = _price.toStringAsFixed(0);
      
      // FIXED LINE BELOW: Changed TextSelectionPosition to TextPosition
      _priceController.selection = TextSelection.fromPosition(
        TextPosition(offset: _priceController.text.length),
      );
    });
  }

  void _setFree() {
    _updatePrice(0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Set your price", 
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))
          ),
          const Text("Price per passenger", style: TextStyle(color: Colors.grey)),
          
          const Spacer(),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleButton(Icons.remove, () => _updatePrice(_price - 10)),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 45, 
                      fontWeight: FontWeight.bold, 
                      color: Color(0xFF2B5145)
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4), 
                    ],
                    onChanged: (value) {
                      setState(() {
                        _price = double.tryParse(value) ?? 0;
                      });
                    },
                    decoration: const InputDecoration(
                      prefixText: "₹",
                      prefixStyle: TextStyle(fontSize: 30, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              
              _circleButton(Icons.add, () => _updatePrice(_price + 10)),
            ],
          ),

          const SizedBox(height: 30),

          Center(
            child: Wrap(
              spacing: 10,
              children: [
                _quickActionChip("Free", _setFree),
                _quickActionChip("Recommended", () => _updatePrice(widget.recommendedPrice)),
              ],
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => widget.onPriceConfirmed(_price),
              child: Text(
                _price == 0 ? "PUBLISH AS FREE RIDE" : "CONFIRM ₹${_price.toStringAsFixed(0)}", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 55, height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: Icon(icon, size: 28, color: primaryGreen),
      ),
    );
  }

  Widget _quickActionChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
      backgroundColor: Colors.white,
      side: BorderSide(color: primaryGreen),
      onPressed: onTap,
    );
  }
}
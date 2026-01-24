import 'package:flutter/material.dart';

class RideStepPrice extends StatefulWidget {
  final double recommendedPrice;
  final Function(double) onPriceConfirmed;
  const RideStepPrice({super.key, required this.recommendedPrice, required this.onPriceConfirmed});

  @override
  State<RideStepPrice> createState() => _RideStepPriceState();
}

class _RideStepPriceState extends State<RideStepPrice> {
  late double _price;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    _price = widget.recommendedPrice;
  }

  void _setFree() {
    setState(() => _price = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    bool isFree = _price == 0;

    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Set your price", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
          const Text("Price per passenger", style: TextStyle(color: Colors.grey)),
          const Spacer(),
          
          // --- PRICE COUNTER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleButton(Icons.remove, () {
                if (_price > 0) setState(() => _price -= 10);
              }),
              
              // Price Display
              Text(
                isFree ? "Free" : "₹${_price.toStringAsFixed(0)}", 
                style: TextStyle(
                  fontSize: isFree ? 40 : 50, 
                  fontWeight: FontWeight.bold, 
                  color: isFree ? primaryGreen : const Color(0xFF2B5145)
                )
              ),
              
              _circleButton(Icons.add, () {
                setState(() => _price += 10);
              }),
            ],
          ),

          const SizedBox(height: 30),

          // --- FREE BUTTON ---
          Center(
            child: InkWell(
              onTap: _setFree,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isFree ? primaryGreen.withOpacity(0.1) : Colors.white,
                  border: Border.all(color: primaryGreen),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volunteer_activism, color: primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Offer for Free",
                      style: TextStyle(
                        color: primaryGreen, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // Recommended Price Hint
          if (!isFree)
            Center(
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                 decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                 child: Text(
                   "Recommended: ₹${widget.recommendedPrice.toStringAsFixed(0)}", 
                   style: const TextStyle(color: Colors.grey, fontSize: 12)
                 ),
               ),
            ),
          
          const Spacer(),

          // --- CONFIRM BUTTON ---
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
                "CONFIRM ${isFree ? 'FREE RIDE' : 'PRICE'}", 
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
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: Icon(icon, size: 30, color: Colors.grey.shade700),
      ),
    );
  }
}
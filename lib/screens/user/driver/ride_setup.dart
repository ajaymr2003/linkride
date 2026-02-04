import 'package:flutter/material.dart';
import 'ride_steps/step_1_location.dart';
import 'ride_steps/step_2_destination.dart';
import 'ride_steps/step_3_route.dart';
import 'ride_steps/step_4_date.dart';
import 'ride_steps/step_5_time.dart';
import 'ride_steps/step_6_vehicle.dart';
import 'ride_steps/step_7_passengers.dart';
import 'ride_steps/step_8_price.dart';
import 'ride_steps/step_9_publish.dart';

class RideSetupScreen extends StatefulWidget {
  const RideSetupScreen({super.key});

  @override
  State<RideSetupScreen> createState() => _RideSetupScreenState();
}

class _RideSetupScreenState extends State<RideSetupScreen> {
  final PageController _pageController = PageController();
  final Color primaryGreen = const Color(0xFF11A860);

  // --- RIDE DATA ---
  // CHANGED: Now storing Objects (Map), not just strings
  Map<String, dynamic> _source = {}; 
  Map<String, dynamic> _destination = {};
  
  String _selectedRoute = "";
  DateTime? _rideDate;
  TimeOfDay? _rideTime;
  Map<String, dynamic>? _selectedVehicle;
  int _passengerCount = 1;
  double _pricePerSeat = 0.0;
  int _currentStep = 0;

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentStep++);
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { _prevPage(); return false; },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: _prevPage),
          title: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: (_currentStep + 1) / 9, backgroundColor: Colors.grey[200], color: primaryGreen, minHeight: 6),
          ),
        ),
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              RideStepLocation(
                title: "Leaving from...", hint: "Current Location", icon: Icons.my_location,
                onLocationSelected: (locData) {
                  setState(() => _source = locData);
                  _nextPage();
                },
              ),
              RideStepDestination(
                onLocationSelected: (locData) {
                  setState(() => _destination = locData);
                  _nextPage();
                },
              ),
              // Pass the maps to step 3
              if(_source.isNotEmpty && _destination.isNotEmpty)
                RideStepRoute(
                  source: _source,
                  destination: _destination,
                  onRouteSelected: (route) {
                    setState(() => _selectedRoute = route);
                    _nextPage();
                  },
                )
              else 
                const Center(child: CircularProgressIndicator()), // Safety fallback

              RideStepDate(onDateSelected: (date) { setState(() => _rideDate = date); _nextPage(); }),
              RideStepTime(onTimeSelected: (time) { setState(() => _rideTime = time); _nextPage(); }),
              RideStepVehicle(onVehicleSelected: (v) { setState(() => _selectedVehicle = v); _nextPage(); }),
              RideStepPassengers(initialCount: _passengerCount, onCountSelected: (count) { setState(() => _passengerCount = count); _nextPage(); }),
              RideStepPrice(recommendedPrice: 150.0, onPriceConfirmed: (price) { setState(() => _pricePerSeat = price); _nextPage(); }),
              
              // Pass the maps to step 9
              RideStepPublish(
                source: _source,
                destination: _destination,
                route: _selectedRoute,
                date: _rideDate,
                time: _rideTime,
                vehicle: _selectedVehicle,
                seats: _passengerCount,
                price: _pricePerSeat,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
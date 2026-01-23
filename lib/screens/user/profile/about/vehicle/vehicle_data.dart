// lib/screens/user/profile/about/vehicle_data.dart

class VehicleData {
  // Keeping this const is fine, it's memory efficient
  static const Map<String, List<String>> carDatabase = {
    "Maruti Suzuki": [
      "Swift", "Baleno", "Dzire", "Alto 800", "Alto K10", "Wagon R", 
      "Brezza", "Ertiga", "Celerio", "Ignis", "S-Presso", "Ciaz", 
      "XL6", "Fronx", "Grand Vitara", "Jimny", "Invicto", "Omni", "800"
    ],
    "Hyundai": [
      "Creta", "Venue", "i20", "Grand i10 Nios", "Verna", "Aura", 
      "Alcazar", "Tucson", "Santro", "Eon", "Xcent", "Accent", "Ioniq 5"
    ],
    "Tata": [
      "Nexon", "Punch", "Harrier", "Safari", "Tiago", "Tigor", "Altroz", 
      "Hexa", "Aria", "Indica", "Indigo", "Nano", "Sumo", "Nexon EV"
    ],
    "Mahindra": [
      "Thar", "Scorpio N", "Scorpio Classic", "XUV700", "XUV300", "Bolero", 
      "Bolero Neo", "Marazzo", "XUV500", "KUV100", "TUV300", "Xylo"
    ],
    "Toyota": [
      "Innova Crysta", "Innova Hycross", "Fortuner", "Glanza", "Urban Cruiser", 
      "Hyryder", "Camry", "Vellfire", "Etios", "Liva", "Corolla Altis"
    ],
    "Honda": [
      "City", "Amaze", "Elevate", "Jazz", "WR-V", "Civic", "CR-V", "Brio", "Mobilio"
    ],
    "Kia": [
      "Seltos", "Sonet", "Carens", "Carnival", "EV6"
    ],
    "MG": [
      "Hector", "Hector Plus", "Astor", "Gloster", "Comet EV", "ZS EV"
    ],
    "Renault": [
      "Kwid", "Triber", "Kiger", "Duster", "Lodgy", "Pulse"
    ],
    "Volkswagen": [
      "Virtus", "Taigun", "Polo", "Vento", "Tiguan", "Ameo", "Jetta", "Passat"
    ],
    "Skoda": [
      "Slavia", "Kushaq", "Octavia", "Superb", "Rapid", "Kodiaq", "Yeti"
    ],
    "Jeep": [
      "Compass", "Meridian", "Wrangler", "Grand Cherokee"
    ],
    "Nissan": [
      "Magnite", "Kicks", "Micra", "Sunny", "Terrano"
    ],
    "BMW": [
      "3 Series", "5 Series", "X1", "X3", "X5", "X7", "Z4"
    ],
    "Mercedes-Benz": [
      "C-Class", "E-Class", "S-Class", "GLA", "GLC", "GLE", "GLS"
    ],
    "Audi": [
      "A4", "A6", "Q3", "Q5", "Q7", "Q8"
    ],
    "Other": [
      "Other Model"
    ]
  };

  static List<String> getBrands() {
    // Create a NEW list using List.from() so we can sort it
    List<String> brands = List.from(carDatabase.keys);
    brands.sort();
    return brands;
  }

  static List<String> getModels(String brand) {
    // FIX: Create a modifiable COPY of the list using List.from()
    // Directly assigning const list to 'models' and sorting causes the crash
    List<String> models = List.from(carDatabase[brand] ?? []);
    models.sort();
    return models;
  }
}
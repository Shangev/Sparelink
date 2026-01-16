/// Vehicle Data Models
/// Migrated from React Native vehicleData.ts

class CarMake {
  final String id;
  final String name;

  CarMake({required this.id, required this.name});

  factory CarMake.fromJson(Map<String, dynamic> json) {
    return CarMake(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class CarModel {
  final String id;
  final String makeId;
  final String name;

  CarModel({
    required this.id,
    required this.makeId,
    required this.name,
  });

  factory CarModel.fromJson(Map<String, dynamic> json) {
    return CarModel(
      id: json['id'],
      makeId: json['makeId'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'makeId': makeId,
      'name': name,
    };
  }
}

/// Static vehicle data (migrated from RN)
class VehicleData {
  // Car Makes (20 total)
  static final List<CarMake> carMakes = [
    CarMake(id: '1', name: 'Toyota'),
    CarMake(id: '2', name: 'Volkswagen'),
    CarMake(id: '3', name: 'Ford'),
    CarMake(id: '4', name: 'Mercedes-Benz'),
    CarMake(id: '5', name: 'BMW'),
    CarMake(id: '6', name: 'Audi'),
    CarMake(id: '7', name: 'Honda'),
    CarMake(id: '8', name: 'Nissan'),
    CarMake(id: '9', name: 'Hyundai'),
    CarMake(id: '10', name: 'Kia'),
    CarMake(id: '11', name: 'Mazda'),
    CarMake(id: '12', name: 'Chevrolet'),
    CarMake(id: '13', name: 'Renault'),
    CarMake(id: '14', name: 'Peugeot'),
    CarMake(id: '15', name: 'Opel'),
    CarMake(id: '16', name: 'Isuzu'),
    CarMake(id: '17', name: 'Suzuki'),
    CarMake(id: '18', name: 'Mitsubishi'),
    CarMake(id: '19', name: 'Jeep'),
    CarMake(id: '20', name: 'Land Rover'),
  ];

  // Car Models (70+ total)
  static final List<CarModel> carModels = [
    // Toyota Models
    CarModel(id: '1-1', makeId: '1', name: 'Corolla'),
    CarModel(id: '1-2', makeId: '1', name: 'Hilux'),
    CarModel(id: '1-3', makeId: '1', name: 'Fortuner'),
    CarModel(id: '1-4', makeId: '1', name: 'Camry'),
    CarModel(id: '1-5', makeId: '1', name: 'RAV4'),
    CarModel(id: '1-6', makeId: '1', name: 'Land Cruiser'),
    CarModel(id: '1-7', makeId: '1', name: 'Avanza'),
    CarModel(id: '1-8', makeId: '1', name: 'Yaris'),
    CarModel(id: '1-9', makeId: '1', name: 'Prado'),
    CarModel(id: '1-10', makeId: '1', name: 'Quantum'),

    // Volkswagen Models
    CarModel(id: '2-1', makeId: '2', name: 'Polo'),
    CarModel(id: '2-2', makeId: '2', name: 'Golf'),
    CarModel(id: '2-3', makeId: '2', name: 'Tiguan'),
    CarModel(id: '2-4', makeId: '2', name: 'Amarok'),
    CarModel(id: '2-5', makeId: '2', name: 'Passat'),
    CarModel(id: '2-6', makeId: '2', name: 'Jetta'),
    CarModel(id: '2-7', makeId: '2', name: 'Touareg'),
    CarModel(id: '2-8', makeId: '2', name: 'T-Roc'),

    // Ford Models
    CarModel(id: '3-1', makeId: '3', name: 'Ranger'),
    CarModel(id: '3-2', makeId: '3', name: 'EcoSport'),
    CarModel(id: '3-3', makeId: '3', name: 'Everest'),
    CarModel(id: '3-4', makeId: '3', name: 'Fiesta'),
    CarModel(id: '3-5', makeId: '3', name: 'Focus'),
    CarModel(id: '3-6', makeId: '3', name: 'Mustang'),
    CarModel(id: '3-7', makeId: '3', name: 'Kuga'),

    // Mercedes-Benz Models
    CarModel(id: '4-1', makeId: '4', name: 'C-Class'),
    CarModel(id: '4-2', makeId: '4', name: 'E-Class'),
    CarModel(id: '4-3', makeId: '4', name: 'GLA'),
    CarModel(id: '4-4', makeId: '4', name: 'GLC'),
    CarModel(id: '4-5', makeId: '4', name: 'A-Class'),
    CarModel(id: '4-6', makeId: '4', name: 'Vito'),

    // BMW Models
    CarModel(id: '5-1', makeId: '5', name: '3 Series'),
    CarModel(id: '5-2', makeId: '5', name: '5 Series'),
    CarModel(id: '5-3', makeId: '5', name: 'X1'),
    CarModel(id: '5-4', makeId: '5', name: 'X3'),
    CarModel(id: '5-5', makeId: '5', name: 'X5'),
    CarModel(id: '5-6', makeId: '5', name: '1 Series'),

    // Audi Models
    CarModel(id: '6-1', makeId: '6', name: 'A3'),
    CarModel(id: '6-2', makeId: '6', name: 'A4'),
    CarModel(id: '6-3', makeId: '6', name: 'Q3'),
    CarModel(id: '6-4', makeId: '6', name: 'Q5'),
    CarModel(id: '6-5', makeId: '6', name: 'Q7'),

    // Honda Models
    CarModel(id: '7-1', makeId: '7', name: 'Civic'),
    CarModel(id: '7-2', makeId: '7', name: 'Accord'),
    CarModel(id: '7-3', makeId: '7', name: 'CR-V'),
    CarModel(id: '7-4', makeId: '7', name: 'Jazz'),
    CarModel(id: '7-5', makeId: '7', name: 'Ballade'),
  ];

  // Years (1980 - 2026)
  static List<String> get years {
    final currentYear = DateTime.now().year;
    final yearsList = <String>[];
    
    for (int year = currentYear + 2; year >= 1980; year--) {
      yearsList.add(year.toString());
    }
    
    return yearsList;
  }

  // Part Categories
  static final List<String> partCategories = [
    'Engine Parts',
    'Transmission',
    'Suspension',
    'Brakes',
    'Electrical',
    'Body Parts',
    'Interior',
    'Exhaust',
    'Cooling System',
    'Fuel System',
    'Steering',
    'Wheels & Tires',
    'Lights',
    'Filters',
    'Belts & Hoses',
    'Other',
  ];

  /// Get models for a specific make
  static List<CarModel> getModelsForMake(String makeId) {
    return carModels.where((model) => model.makeId == makeId).toList();
  }

  /// Get make by ID
  static CarMake? getMakeById(String id) {
    try {
      return carMakes.firstWhere((make) => make.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get model by ID
  static CarModel? getModelById(String id) {
    try {
      return carModels.firstWhere((model) => model.id == id);
    } catch (e) {
      return null;
    }
  }
}

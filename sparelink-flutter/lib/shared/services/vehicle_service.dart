import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

/// Vehicle Service Provider
final vehicleServiceProvider = Provider<VehicleService>((ref) {
  final storageService = ref.read(storageServiceProvider);
  return VehicleService(storageService);
});

/// Saved Vehicle Model
class SavedVehicle {
  final String id;
  final String makeId;
  final String makeName;
  final String modelId;
  final String modelName;
  final String year;
  final String? vin;
  final String? engineCode;
  final String? nickname;
  final bool isDefault;
  final DateTime createdAt;

  SavedVehicle({
    required this.id,
    required this.makeId,
    required this.makeName,
    required this.modelId,
    required this.modelName,
    required this.year,
    this.vin,
    this.engineCode,
    this.nickname,
    this.isDefault = false,
    required this.createdAt,
  });

  factory SavedVehicle.fromJson(Map<String, dynamic> json) {
    return SavedVehicle(
      id: json['id'] as String,
      makeId: json['make_id'] as String,
      makeName: json['make_name'] as String,
      modelId: json['model_id'] as String,
      modelName: json['model_name'] as String,
      year: json['year'] as String,
      vin: json['vin'] as String?,
      engineCode: json['engine_code'] as String?,
      nickname: json['nickname'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'make_id': makeId,
    'make_name': makeName,
    'model_id': modelId,
    'model_name': modelName,
    'year': year,
    'vin': vin,
    'engine_code': engineCode,
    'nickname': nickname,
    'is_default': isDefault,
    'created_at': createdAt.toIso8601String(),
  };

  String get displayName => nickname ?? '$year $makeName $modelName';
}

/// VIN Decode Result
class VinDecodeResult {
  final String? make;
  final String? model;
  final String? year;
  final String? engineCode;
  final String? bodyType;
  final String? transmission;
  final bool success;
  final String? error;

  VinDecodeResult({
    this.make,
    this.model,
    this.year,
    this.engineCode,
    this.bodyType,
    this.transmission,
    this.success = false,
    this.error,
  });
}

/// Vehicle Service
/// 
/// Manages saved vehicles, VIN decoding, and vehicle data
class VehicleService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StorageService _storageService;

  VehicleService(this._storageService);

  // ===========================================
  // SAVED VEHICLES
  // ===========================================

  /// Get all saved vehicles for current user
  Future<List<SavedVehicle>> getSavedVehicles() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('saved_vehicles')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((v) => SavedVehicle.fromJson(v))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save a new vehicle
  Future<SavedVehicle?> saveVehicle({
    required String makeId,
    required String makeName,
    required String modelId,
    required String modelName,
    required String year,
    String? vin,
    String? engineCode,
    String? nickname,
    bool setAsDefault = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      // If setting as default, unset other defaults first
      if (setAsDefault) {
        await _supabase
            .from('saved_vehicles')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      final response = await _supabase
          .from('saved_vehicles')
          .insert({
            'user_id': userId,
            'make_id': makeId,
            'make_name': makeName,
            'model_id': modelId,
            'model_name': modelName,
            'year': year,
            'vin': vin,
            'engine_code': engineCode,
            'nickname': nickname,
            'is_default': setAsDefault,
          })
          .select()
          .single();

      return SavedVehicle.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Delete a saved vehicle
  Future<bool> deleteVehicle(String vehicleId) async {
    try {
      await _supabase
          .from('saved_vehicles')
          .delete()
          .eq('id', vehicleId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Set a vehicle as default
  Future<bool> setDefaultVehicle(String vehicleId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Unset all defaults
      await _supabase
          .from('saved_vehicles')
          .update({'is_default': false})
          .eq('user_id', userId);

      // Set new default
      await _supabase
          .from('saved_vehicles')
          .update({'is_default': true})
          .eq('id', vehicleId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get default vehicle
  Future<SavedVehicle?> getDefaultVehicle() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('saved_vehicles')
          .select()
          .eq('user_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      if (response == null) return null;
      return SavedVehicle.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // ===========================================
  // VIN DECODING
  // ===========================================

  /// Decode VIN number to get vehicle details
  /// Uses NHTSA API (free, US-focused but works for many vehicles)
  Future<VinDecodeResult> decodeVin(String vin) async {
    try {
      // Validate VIN format (17 characters)
      if (vin.length != 17) {
        return VinDecodeResult(
          success: false,
          error: 'VIN must be exactly 17 characters',
        );
      }

      // Use NHTSA vPIC API for decoding
      // This is a free API that works globally for most manufacturers
      final response = await _supabase.functions.invoke(
        'decode-vin',
        body: {'vin': vin},
      );

      if (response.status != 200) {
        // Fallback: Try to extract basic info from VIN
        return _decodeVinLocally(vin);
      }

      final data = response.data as Map<String, dynamic>;
      return VinDecodeResult(
        success: true,
        make: data['make'] as String?,
        model: data['model'] as String?,
        year: data['year'] as String?,
        engineCode: data['engineCode'] as String?,
        bodyType: data['bodyType'] as String?,
        transmission: data['transmission'] as String?,
      );
    } catch (e) {
      // Fallback to local decoding
      return _decodeVinLocally(vin);
    }
  }

  /// Local VIN decoding (basic extraction from VIN structure)
  VinDecodeResult _decodeVinLocally(String vin) {
    try {
      // VIN position 10 indicates model year
      final yearChar = vin[9];
      final year = _decodeYearFromVin(yearChar);

      // World Manufacturer Identifier (first 3 chars)
      final wmi = vin.substring(0, 3);
      final make = _getMakeFromWmi(wmi);

      return VinDecodeResult(
        success: make != null,
        make: make,
        year: year,
        error: make == null ? 'Could not decode VIN. Please enter vehicle details manually.' : null,
      );
    } catch (e) {
      return VinDecodeResult(
        success: false,
        error: 'Invalid VIN format',
      );
    }
  }

  /// Decode year from VIN position 10
  String? _decodeYearFromVin(String char) {
    const yearCodes = {
      'A': '2010', 'B': '2011', 'C': '2012', 'D': '2013', 'E': '2014',
      'F': '2015', 'G': '2016', 'H': '2017', 'J': '2018', 'K': '2019',
      'L': '2020', 'M': '2021', 'N': '2022', 'P': '2023', 'R': '2024',
      'S': '2025', 'T': '2026', 'V': '2027', 'W': '2028', 'X': '2029',
      'Y': '2030', '1': '2001', '2': '2002', '3': '2003', '4': '2004',
      '5': '2005', '6': '2006', '7': '2007', '8': '2008', '9': '2009',
    };
    return yearCodes[char.toUpperCase()];
  }

  /// Get make from World Manufacturer Identifier
  String? _getMakeFromWmi(String wmi) {
    // Common South African and international WMIs
    const wmiMakes = {
      // South African
      'AAV': 'Volkswagen', 'ADH': 'Hyundai', 'AFA': 'Ford',
      // German
      'WBA': 'BMW', 'WBS': 'BMW M', 'WDB': 'Mercedes-Benz', 'WDD': 'Mercedes-Benz',
      'WF0': 'Ford', 'WVW': 'Volkswagen', 'WAU': 'Audi', 'WP0': 'Porsche',
      // Japanese
      'JHM': 'Honda', 'JN1': 'Nissan', 'JT': 'Toyota', 'JM1': 'Mazda',
      'JS': 'Suzuki', 'JF': 'Subaru', 'KM': 'Hyundai', 'KN': 'Kia',
      // American
      '1G': 'General Motors', '1F': 'Ford', '1C': 'Chrysler', '2G': 'GM Canada',
      '3G': 'GM Mexico', '3F': 'Ford Mexico', '5Y': 'Toyota USA',
      // Korean
      'KMH': 'Hyundai', 'KNA': 'Kia', 'KNM': 'Renault Samsung',
      // Others
      'SAJ': 'Jaguar', 'SAL': 'Land Rover', 'SCC': 'Lotus', 'VF1': 'Renault',
      'ZAM': 'Maserati', 'ZAR': 'Alfa Romeo', 'ZFF': 'Ferrari',
    };

    // Try 3-char match first
    if (wmiMakes.containsKey(wmi)) {
      return wmiMakes[wmi];
    }
    // Try 2-char match
    final twoChar = wmi.substring(0, 2);
    for (final entry in wmiMakes.entries) {
      if (entry.key.startsWith(twoChar)) {
        return entry.value;
      }
    }
    return null;
  }

  // ===========================================
  // PART NUMBER LOOKUP
  // ===========================================

  /// Search for parts by OEM part number
  Future<List<Map<String, dynamic>>> searchByPartNumber(String partNumber) async {
    try {
      final response = await _supabase
          .from('parts')
          .select('id, name, category_id, oem_number, cross_references')
          .or('oem_number.ilike.%$partNumber%,cross_references.cs.{$partNumber}')
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}

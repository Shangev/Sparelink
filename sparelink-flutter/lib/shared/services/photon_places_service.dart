import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/api_constants.dart';

/// Photon Places Service for Address Autocomplete (OpenStreetMap)
/// Free, no API key required!
/// Documentation: https://photon.komoot.io/
class PhotonPlacesService {
  static const String _baseUrl = 'https://photon.komoot.io';
  
  /// Search for places matching the query (South Africa focused)
  /// First searches Photon (OpenStreetMap), then falls back to local registry
  static Future<List<PlacePrediction>> searchPlaces(String query) async {
    if (query.isEmpty || query.length < 3) return [];
    
    debugPrint('🔍 Photon: Searching for "$query"');
    
    List<PlacePrediction> predictions = [];
    
    // Step 1: Search Photon (OpenStreetMap)
    try {
      final url = Uri.parse('$_baseUrl/api/').replace(queryParameters: {
        'q': query,
        'lat': ApiConstants.defaultLatitude.toString(),
        'lon': ApiConstants.defaultLongitude.toString(),
        'limit': '10',
        'lang': 'en',
      });
      
      debugPrint('🌐 Photon URL: $url');
      
      final response = await http.get(url);
      debugPrint('📡 Photon Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];
        
        debugPrint('📦 Photon Results: ${features.length} places found');
        
        predictions = features
            .map((f) => PlacePrediction.fromPhotonFeature(f))
            .where((p) => p.description.isNotEmpty)
            .toList();
      } else {
        debugPrint('❌ Photon HTTP Error: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('❌ Photon search error: $e');
      debugPrint('Stack: $stack');
    }
    
    // Step 2: If Photon has no results, search local registry
    if (predictions.isEmpty) {
      debugPrint('🏠 Photon empty - searching Sparelink Local Address Registry...');
      final localResults = await searchLocalRegistry(query);
      predictions.addAll(localResults);
      debugPrint('🏠 Local Registry: ${localResults.length} addresses found');
    }
    
    return predictions;
  }
  
  /// Search the Sparelink Local Address Registry (Supabase)
  static Future<List<PlacePrediction>> searchLocalRegistry(String query) async {
    try {
      final response = await Supabase.instance.client
          .rpc('search_local_addresses', params: {
            'search_query': query,
            'result_limit': 10,
          });
      
      if (response == null) return [];
      
      final results = (response as List).map((row) {
        return PlacePrediction.fromLocalRegistry(row as Map<String, dynamic>);
      }).toList();
      
      return results;
    } catch (e) {
      debugPrint('❌ Local registry search error: $e');
      return [];
    }
  }
  
  /// Save a manually entered address to the local registry
  static Future<String?> saveToLocalRegistry(PlaceDetails details) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      final response = await Supabase.instance.client
          .from('local_addresses')
          .insert({
            'street_address': details.streetName ?? details.formattedAddress.split(',').first,
            'suburb': details.suburb,
            'city': details.city,
            'province': details.province,
            'postal_code': details.postalCode,
            'country': details.country ?? 'South Africa',
            'formatted_address': details.formattedAddress,
            'latitude': details.latitude,
            'longitude': details.longitude,
            'created_by': user?.id,
          })
          .select('id')
          .single();
      
      final addressId = response['id'] as String?;
      debugPrint('✅ Address saved to local registry: $addressId');
      return addressId;
    } on PostgrestException catch (e) {
      // Handle duplicate - address already exists
      if (e.code == '23505') {
        debugPrint('ℹ️ Address already exists in local registry');
        return null;
      }
      debugPrint('❌ Error saving to local registry: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Error saving to local registry: $e');
      return null;
    }
  }
  
  /// Increment use count when a local address is selected
  static Future<void> incrementAddressUseCount(String addressId) async {
    try {
      await Supabase.instance.client
          .rpc('increment_address_use_count', params: {'address_id': addressId});
      debugPrint('📈 Incremented use count for address: $addressId');
    } catch (e) {
      debugPrint('⚠️ Failed to increment use count: $e');
    }
  }
  
  /// Get place details using reverse geocoding
  /// Since Photon returns full details in search, this is mainly for coordinate-based lookups
  static Future<PlaceDetails?> getPlaceDetails(String featureId) async {
    debugPrint('📍 Photon: Getting details for $featureId');
    
    // For Photon, the featureId contains encoded lat,lon
    // Format: "lat,lon" or the full feature JSON
    try {
      final parts = featureId.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0]);
        final lon = double.tryParse(parts[1]);
        
        if (lat != null && lon != null) {
          return await reverseGeocode(lat, lon);
        }
      }
      
      // If featureId is JSON-encoded feature data
      try {
        final featureData = json.decode(featureId);
        return PlaceDetails.fromPhotonFeature(featureData);
      } catch (_) {
        debugPrint('⚠️ Could not parse feature data');
      }
    } catch (e, stack) {
      debugPrint('❌ Photon details error: $e');
      debugPrint('Stack: $stack');
    }
    
    return null;
  }
  
  /// Reverse geocoding - get address from coordinates
  static Future<PlaceDetails?> reverseGeocode(double lat, double lon) async {
    debugPrint('📍 Photon: Reverse geocoding $lat, $lon');
    
    try {
      final url = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'lang': 'en',
      });
      
      debugPrint('🌐 Photon Reverse URL: $url');
      
      final response = await http.get(url);
      debugPrint('📡 Photon Reverse Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];
        
        if (features.isNotEmpty) {
          return PlaceDetails.fromPhotonFeature(features.first);
        }
      } else {
        debugPrint('❌ Photon Reverse HTTP Error: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('❌ Photon reverse geocode error: $e');
      debugPrint('Stack: $stack');
    }
    
    return null;
  }
}

/// Represents a place prediction from Photon autocomplete or Local Registry
class PlacePrediction {
  final String placeId;        // Encoded coordinates or OSM ID
  final String description;    // Full formatted address
  final String mainText;       // Primary name/street
  final String secondaryText;  // City, region, country
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> rawFeature;  // Store raw data for details lookup
  final bool isFromLocalRegistry;  // True if from Sparelink Local Registry
  final String? localRegistryId;   // UUID if from local registry
  
  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
    this.rawFeature = const {},
    this.isFromLocalRegistry = false,
    this.localRegistryId,
  });
  
  /// Create from Sparelink Local Address Registry result
  factory PlacePrediction.fromLocalRegistry(Map<String, dynamic> row) {
    final streetAddress = row['street_address'] as String? ?? '';
    final suburb = row['suburb'] as String? ?? '';
    final city = row['city'] as String? ?? '';
    final province = row['province'] as String? ?? '';
    final country = row['country'] as String? ?? 'South Africa';
    final formattedAddress = row['formatted_address'] as String? ?? '';
    final lat = row['latitude'] as double?;
    final lon = row['longitude'] as double?;
    final addressId = row['id'] as String?;
    
    // Build main text
    String mainText = streetAddress;
    if (mainText.isEmpty) {
      mainText = suburb.isNotEmpty ? suburb : city;
    }
    
    // Build secondary text
    final secondaryParts = <String>[];
    if (suburb.isNotEmpty && suburb != mainText) secondaryParts.add(suburb);
    if (city.isNotEmpty && city != mainText && city != suburb) secondaryParts.add(city);
    if (province.isNotEmpty) secondaryParts.add(province);
    if (country.isNotEmpty) secondaryParts.add(country);
    final secondaryText = secondaryParts.join(', ');
    
    return PlacePrediction(
      placeId: addressId ?? (lat != null && lon != null ? '$lat,$lon' : formattedAddress),
      description: formattedAddress,
      mainText: mainText,
      secondaryText: secondaryText,
      latitude: lat,
      longitude: lon,
      isFromLocalRegistry: true,
      localRegistryId: addressId,
      rawFeature: row,
    );
  }
  
  factory PlacePrediction.fromPhotonFeature(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = geometry['coordinates'] as List? ?? [];
    
    final lon = coordinates.isNotEmpty ? coordinates[0]?.toDouble() : null;
    final lat = coordinates.length > 1 ? coordinates[1]?.toDouble() : null;
    
    // Extract address components
    final name = properties['name'] as String? ?? '';
    final street = properties['street'] as String? ?? '';
    final houseNumber = properties['housenumber'] as String? ?? '';
    final suburb = properties['suburb'] as String? ?? 
                   properties['district'] as String? ?? '';
    final city = properties['city'] as String? ?? 
                 properties['town'] as String? ?? 
                 properties['village'] as String? ?? '';
    final state = properties['state'] as String? ?? '';
    final country = properties['country'] as String? ?? '';
    // ignore: unused_local_variable - available for future use
    final _ = properties['postcode'] as String? ?? '';
    
    // Build main text (primary identifier)
    String mainText = name;
    if (mainText.isEmpty && street.isNotEmpty) {
      mainText = houseNumber.isNotEmpty ? '$houseNumber $street' : street;
    }
    if (mainText.isEmpty) {
      mainText = suburb.isNotEmpty ? suburb : city;
    }
    
    // Build secondary text (location context)
    final secondaryParts = <String>[];
    if (suburb.isNotEmpty && suburb != mainText) secondaryParts.add(suburb);
    if (city.isNotEmpty && city != mainText && city != suburb) secondaryParts.add(city);
    if (state.isNotEmpty) secondaryParts.add(state);
    if (country.isNotEmpty) secondaryParts.add(country);
    final secondaryText = secondaryParts.join(', ');
    
    // Build full description
    final descParts = <String>[];
    if (mainText.isNotEmpty) descParts.add(mainText);
    if (secondaryText.isNotEmpty) descParts.add(secondaryText);
    final description = descParts.join(', ');
    
    // Create a unique ID from coordinates or OSM ID
    final osmId = properties['osm_id']?.toString() ?? '';
    final placeId = lat != null && lon != null 
        ? '$lat,$lon' 
        : osmId;
    
    return PlacePrediction(
      placeId: placeId,
      description: description,
      mainText: mainText,
      secondaryText: secondaryText,
      latitude: lat,
      longitude: lon,
      rawFeature: feature,
    );
  }
  
  /// Convert to PlaceDetails for direct use
  PlaceDetails toPlaceDetails() {
    return PlaceDetails.fromPhotonFeature(rawFeature);
  }
}

/// Represents detailed place information with extracted suburb and city
class PlaceDetails {
  final String formattedAddress;
  final String? streetNumber;
  final String? streetName;
  final String? suburb;       // district or suburb
  final String? city;         // city, town, or village
  final String? province;     // state
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? country;
  
  PlaceDetails({
    required this.formattedAddress,
    this.streetNumber,
    this.streetName,
    this.suburb,
    this.city,
    this.province,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.country,
  });
  
  factory PlaceDetails.fromPhotonFeature(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = geometry['coordinates'] as List? ?? [];
    
    final lon = coordinates.isNotEmpty ? coordinates[0]?.toDouble() : null;
    final lat = coordinates.length > 1 ? coordinates[1]?.toDouble() : null;
    
    // Extract all address components
    final name = properties['name'] as String? ?? '';
    final street = properties['street'] as String?;
    final houseNumber = properties['housenumber'] as String?;
    final suburb = properties['suburb'] as String? ?? 
                   properties['district'] as String?;
    final city = properties['city'] as String? ?? 
                 properties['town'] as String? ?? 
                 properties['village'] as String?;
    final state = properties['state'] as String?;
    final country = properties['country'] as String?;
    final postcode = properties['postcode'] as String?;
    
    // Build formatted address
    final addressParts = <String>[];
    if (houseNumber != null && street != null) {
      addressParts.add('$houseNumber $street');
    } else if (street != null) {
      addressParts.add(street);
    } else if (name.isNotEmpty) {
      addressParts.add(name);
    }
    if (suburb != null) addressParts.add(suburb);
    if (city != null) addressParts.add(city);
    if (state != null) addressParts.add(state);
    if (postcode != null) addressParts.add(postcode);
    if (country != null) addressParts.add(country);
    
    final formattedAddress = addressParts.join(', ');
    
    return PlaceDetails(
      formattedAddress: formattedAddress,
      streetNumber: houseNumber,
      streetName: street,
      suburb: suburb,
      city: city,
      province: state,
      postalCode: postcode,
      latitude: lat,
      longitude: lon,
      country: country,
    );
  }
  
  /// Get full street address (number + name)
  String get streetAddress {
    if (streetNumber != null && streetName != null) {
      return '$streetNumber $streetName';
    }
    return streetName ?? '';
  }
}

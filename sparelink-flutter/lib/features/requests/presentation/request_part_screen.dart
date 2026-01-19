import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/services/vehicle_service.dart';
import '../../../shared/services/draft_service.dart';

class RequestPartScreen extends ConsumerStatefulWidget {
  const RequestPartScreen({super.key});

  @override
  ConsumerState<RequestPartScreen> createState() => _RequestPartScreenState();
}

class _RequestPartScreenState extends ConsumerState<RequestPartScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isDecodingVin = false;
  
  // Vehicle data
  List<Map<String, dynamic>> _vehicleMakes = [];
  List<Map<String, dynamic>> _vehicleModels = [];
  List<SavedVehicle> _savedVehicles = [];
  String? _selectedMakeId;
  String? _selectedMakeName;
  String? _selectedModelId;
  String? _selectedModelName;
  String? _selectedYear;
  final _vinController = TextEditingController();
  final _engineCodeController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Parts data
  List<Map<String, dynamic>> _partCategories = [];
  List<Map<String, dynamic>> _parts = [];
  List<Map<String, dynamic>> _selectedParts = [];
  List<Map<String, dynamic>> _partNumberResults = [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  
  // New fields
  String _urgencyLevel = 'normal'; // urgent, normal, flexible
  double? _budgetMin;
  double? _budgetMax;
  bool _hasDraft = false;
  List<RequestTemplate> _templates = [];
  
  // Generate years from 2000 to current year
  List<String> get _years {
    final currentYear = DateTime.now().year;
    return List.generate(currentYear - 1999, (i) => (currentYear - i).toString());
  }

  @override
  void initState() {
    super.initState();
    _loadVehicleMakes();
    _loadPartCategories();
    _loadSavedVehicles();
    _loadDraft();
    _loadTemplates();
  }

  @override
  void dispose() {
    _saveDraftOnExit();
    _vinController.dispose();
    _engineCodeController.dispose();
    _partNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSavedVehicles() async {
    final vehicleService = ref.read(vehicleServiceProvider);
    final vehicles = await vehicleService.getSavedVehicles();
    if (mounted) {
      setState(() => _savedVehicles = vehicles);
    }
  }
  
  Future<void> _loadDraft() async {
    final draftService = ref.read(draftServiceProvider);
    final draft = await draftService.loadDraft();
    if (draft != null && !draft.isEmpty && mounted) {
      setState(() => _hasDraft = true);
      _showDraftDialog(draft);
    }
  }
  
  Future<void> _loadTemplates() async {
    final draftService = ref.read(draftServiceProvider);
    final templates = await draftService.getTemplates();
    if (mounted) {
      setState(() => _templates = templates);
    }
  }
  
  void _showDraftDialog(RequestDraft draft) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Resume Draft?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You have an unsaved request${draft.hasVehicleInfo ? ' for ${draft.year} ${draft.makeName} ${draft.modelName}' : ''}. Would you like to continue?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(draftServiceProvider).clearDraft();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restoreDraft(draft);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
  
  void _restoreDraft(RequestDraft draft) {
    setState(() {
      _selectedMakeId = draft.makeId;
      _selectedMakeName = draft.makeName;
      _selectedModelId = draft.modelId;
      _selectedModelName = draft.modelName;
      _selectedYear = draft.year;
      _vinController.text = draft.vin ?? '';
      _engineCodeController.text = draft.engineCode ?? '';
      _selectedParts = List.from(draft.selectedParts);
      _urgencyLevel = draft.urgencyLevel ?? 'normal';
      _budgetMin = draft.budgetMin;
      _budgetMax = draft.budgetMax;
      _notesController.text = draft.notes ?? '';
      if (draft.hasVehicleInfo) _currentStep = 1;
    });
    if (draft.makeId != null) _loadVehicleModels(draft.makeId!);
  }
  
  Future<void> _saveDraftOnExit() async {
    if (_selectedMakeId == null && _selectedParts.isEmpty) return;
    
    final draft = RequestDraft(
      makeId: _selectedMakeId,
      makeName: _selectedMakeName,
      modelId: _selectedModelId,
      modelName: _selectedModelName,
      year: _selectedYear,
      vin: _vinController.text.isNotEmpty ? _vinController.text : null,
      engineCode: _engineCodeController.text.isNotEmpty ? _engineCodeController.text : null,
      selectedParts: _selectedParts,
      urgencyLevel: _urgencyLevel,
      budgetMin: _budgetMin,
      budgetMax: _budgetMax,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      savedAt: DateTime.now(),
    );
    
    await ref.read(draftServiceProvider).saveDraft(draft);
  }
  
  Future<void> _decodeVin() async {
    final vin = _vinController.text.trim().toUpperCase();
    if (vin.length != 17) {
      _showError('VIN must be exactly 17 characters');
      return;
    }
    
    setState(() => _isDecodingVin = true);
    
    final vehicleService = ref.read(vehicleServiceProvider);
    final result = await vehicleService.decodeVin(vin);
    
    if (mounted) {
      setState(() => _isDecodingVin = false);
      
      if (result.success) {
        // Try to match make in our database
        if (result.make != null) {
          final make = _vehicleMakes.firstWhere(
            (m) => (m['name'] as String).toLowerCase().contains(result.make!.toLowerCase()),
            orElse: () => {},
          );
          if (make.isNotEmpty) {
            setState(() {
              _selectedMakeId = make['id'] as String;
              _selectedMakeName = make['name'] as String;
            });
            await _loadVehicleModels(make['id'] as String);
          }
        }
        if (result.year != null) {
          setState(() => _selectedYear = result.year);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VIN decoded: ${result.make ?? ''} ${result.model ?? ''} ${result.year ?? ''}'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        _showError(result.error ?? 'Could not decode VIN');
      }
    }
  }
  
  Future<void> _searchByPartNumber() async {
    final partNumber = _partNumberController.text.trim();
    if (partNumber.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    final vehicleService = ref.read(vehicleServiceProvider);
    final results = await vehicleService.searchByPartNumber(partNumber);
    
    if (mounted) {
      setState(() {
        _partNumberResults = results;
        _isLoading = false;
      });
      
      if (results.isEmpty) {
        _showError('No parts found with that number');
      }
    }
  }
  
  void _selectSavedVehicle(SavedVehicle vehicle) {
    setState(() {
      _selectedMakeId = vehicle.makeId;
      _selectedMakeName = vehicle.makeName;
      _selectedModelId = vehicle.modelId;
      _selectedModelName = vehicle.modelName;
      _selectedYear = vehicle.year;
      _vinController.text = vehicle.vin ?? '';
      _engineCodeController.text = vehicle.engineCode ?? '';
    });
    _loadVehicleModels(vehicle.makeId);
  }
  
  Future<void> _saveCurrentVehicle() async {
    if (_selectedMakeId == null || _selectedModelId == null || _selectedYear == null) {
      _showError('Please complete vehicle details first');
      return;
    }
    
    final nicknameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Save Vehicle', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_selectedYear $_selectedMakeName $_selectedModelName', style: const TextStyle(color: AppTheme.accentGreen)),
            const SizedBox(height: 16),
            TextField(
              controller: nicknameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nickname (optional)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final vehicleService = ref.read(vehicleServiceProvider);
      final saved = await vehicleService.saveVehicle(
        makeId: _selectedMakeId!,
        makeName: _selectedMakeName!,
        modelId: _selectedModelId!,
        modelName: _selectedModelName!,
        year: _selectedYear!,
        vin: _vinController.text.isNotEmpty ? _vinController.text : null,
        engineCode: _engineCodeController.text.isNotEmpty ? _engineCodeController.text : null,
        nickname: nicknameController.text.isNotEmpty ? nicknameController.text : null,
        setAsDefault: _savedVehicles.isEmpty,
      );
      
      if (saved != null && mounted) {
        _loadSavedVehicles();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle saved!'), backgroundColor: AppTheme.accentGreen),
        );
      }
    }
  }

  Future<void> _loadVehicleMakes() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('vehicle_makes')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
      setState(() {
        _vehicleMakes = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load vehicle makes');
    }
  }

  Future<void> _loadVehicleModels(String makeId) async {
    try {
      debugPrint('🚗 Loading models for make_id: $makeId');
      final response = await Supabase.instance.client
          .from('vehicle_models')
          .select('id, name, make_id')
          .eq('make_id', makeId)
          .order('name');
      debugPrint('🚗 Models response: $response');
      debugPrint('🚗 Found ${(response as List).length} models');
      setState(() {
        _vehicleModels = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('🚗 Error loading models: $e');
      _showError('Failed to load models');
    }
  }

  Future<void> _loadPartCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('part_categories')
          .select('id, name, icon')
          .order('sort_order');
      setState(() {
        _partCategories = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showError('Failed to load part categories');
    }
  }

  Future<void> _loadParts(String categoryId) async {
    try {
      final response = await Supabase.instance.client
          .from('parts')
          .select('id, name')
          .eq('category_id', categoryId)
          .order('name');
      setState(() {
        _parts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showError('Failed to load parts');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  void _showNoShopsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.mapPinOff, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('No Shops Available', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Sorry, there are no spare parts shops in your area yet.\n\nYour request has been saved and you\'ll be notified when shops become available in your suburb or city.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/home');
            },
            child: const Text('Go Home', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/my-requests');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            child: const Text('View My Requests'),
          ),
        ],
      ),
    );
  }

  void _addPart(String partId, String partName) {
    if (_selectedParts.any((p) => p['part_id'] == partId)) {
      _showError('Part already added');
      return;
    }
    setState(() {
      _selectedParts.add({
        'part_id': partId,
        'part_name': partName,
        'category_id': _selectedCategoryId,
        'category_name': _selectedCategoryName,
        'quantity': 1,
        'image_url': null,
        'notes': '',
      });
    });
  }

  void _removePart(int index) {
    setState(() {
      _selectedParts.removeAt(index);
    });
  }

  void _updatePartQuantity(int index, int quantity) {
    setState(() {
      _selectedParts[index]['quantity'] = quantity;
    });
  }

  Future<void> _submitRequest() async {
    if (_selectedParts.isEmpty) {
      _showError('Please add at least one part');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final storageService = ref.read(storageServiceProvider);
      final mechanicId = await storageService.getUserId();
      final suburb = await _getMechanicSuburb();
      
      // Check if mechanic has set their suburb
      if (suburb == null || suburb.isEmpty) {
        _showError('Please set your suburb in Profile before submitting requests');
        setState(() => _isSubmitting = false);
        return;
      }

      // Get the first image URL from selected parts (if any)
      final firstImageUrl = _selectedParts
          .where((p) => p['image_url'] != null)
          .map((p) => p['image_url'] as String)
          .firstOrNull;

      // Create part request - base fields only (guaranteed to exist)
      final baseRequestData = <String, dynamic>{
        'mechanic_id': mechanicId,
        'vehicle_make': _selectedMakeName,
        'vehicle_model': _selectedModelName,
        'vehicle_year': int.parse(_selectedYear!),
        'vin_number': _vinController.text.isNotEmpty ? _vinController.text : null,
        'engine_code': _engineCodeController.text.isNotEmpty ? _engineCodeController.text : null,
        'part_category': _selectedParts.map((p) => p['category_name']).toSet().join(', '),
        'status': 'pending',
        'suburb': suburb,
        'image_url': firstImageUrl,
      };
      
      // Try with extended fields first, fallback to base if schema not updated
      Map<String, dynamic>? requestResponse;
      
      try {
        // Attempt with new columns (urgency, budget, notes)
        final extendedData = Map<String, dynamic>.from(baseRequestData);
        extendedData['urgency_level'] = _urgencyLevel;
        if (_budgetMin != null) extendedData['budget_min'] = _budgetMin;
        if (_budgetMax != null) extendedData['budget_max'] = _budgetMax;
        if (_notesController.text.isNotEmpty) extendedData['notes'] = _notesController.text;
        
        requestResponse = await Supabase.instance.client
            .from('part_requests')
            .insert(extendedData)
            .select()
            .single();
      } catch (e) {
        // Fallback: Schema may not have new columns yet
        print('Extended insert failed, falling back to base: $e');
        requestResponse = await Supabase.instance.client
            .from('part_requests')
            .insert(baseRequestData)
            .select()
            .single();
        
        // Show user a note that some features weren't saved
        if (mounted && (_budgetMin != null || _budgetMax != null || _urgencyLevel != 'normal')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note: Budget and urgency preferences saved locally. Database update pending.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      final requestId = requestResponse['id'] as String;

      // Insert request items
      for (final part in _selectedParts) {
        await Supabase.instance.client.from('request_items').insert({
          'request_id': requestId,
          'part_category_id': part['category_id'],
          'part_id': part['part_id'],
          'part_name': part['part_name'],
          'quantity': part['quantity'],
          'image_url': part['image_url'],
          'notes': part['notes'],
        });
      }
      
      // Notify nearby shops (same suburb first, then city, then none)
      final shopsFound = await _notifyNearbyShops(
        requestId: requestId,
        suburb: suburb,
        partNames: _selectedParts.map((p) => p['part_name'] as String).join(', '),
        vehicleInfo: '$_selectedYear $_selectedMakeName $_selectedModelName',
      );

      if (mounted) {
        if (shopsFound) {
          // Navigate to request chats to see shop responses
          context.go('/request-chats/$requestId');
        } else {
          // No shops found - show message and stay on page
          _showNoShopsDialog();
        }
      }
    } catch (e) {
      _showError('Failed to submit request: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
  
  /// Notify nearby shops about the new request
  /// Logic: 1) Same suburb (up to 5), 2) If none, try same city, 3) If none, show "no shops"
  /// Note: Works with 1-5 shops - doesn't require exactly 5
  Future<bool> _notifyNearbyShops({
    required String requestId,
    required String suburb,
    required String partNames,
    required String vehicleInfo,
  }) async {
    try {
      // Get mechanic's city for fallback
      final mechanicCity = await _getMechanicCity();
      
      // Clean the suburb/city strings (trim whitespace)
      final cleanSuburb = suburb.trim();
      final cleanCity = mechanicCity?.trim();
      
      debugPrint('🏪 Looking for shops in suburb: "$cleanSuburb"');
      debugPrint('🏪 Mechanic city fallback: "$cleanCity"');
      
      // Step 1: Get shops in same suburb (up to 5)
      // Using ilike for case-insensitive matching
      var shops = await Supabase.instance.client
          .from('shops')
          .select('id, owner_id, name, suburb, city')
          .ilike('suburb', '%$cleanSuburb%')
          .limit(5);
      
      debugPrint('🏪 Shops found in suburb "$cleanSuburb": ${(shops as List).length}');
      debugPrint('🏪 Shops data: $shops');
      
      // Step 2: If no shops in suburb, try same city
      if (shops.isEmpty && cleanCity != null && cleanCity.isNotEmpty) {
        debugPrint('🏪 No shops in suburb, trying city: "$cleanCity"');
        shops = await Supabase.instance.client
            .from('shops')
            .select('id, owner_id, name, suburb, city')
            .ilike('city', '%$cleanCity%')
            .limit(5);
        debugPrint('🏪 Shops found in city "$cleanCity": ${shops.length}');
        debugPrint('🏪 Shops data: $shops');
      }
      
      // Step 3: If still no shops, return false (no shops available)
      // Even 1 shop is enough - we don't require exactly 5
      if (shops.isEmpty) {
        debugPrint('🏪 NO SHOPS FOUND - returning false');
        // Debug: Let's see ALL shops in the database
        final allShops = await Supabase.instance.client
            .from('shops')
            .select('id, name, suburb, city');
        debugPrint('🏪 ALL SHOPS IN DATABASE: $allShops');
        return false;
      }
      
      debugPrint('🏪 ✅ Found ${shops.length} shop(s) - proceeding to create request_chats');
      
      // Create a request_chat for each shop (this enables the chat flow)
      for (final shop in shops) {
        if (shop['owner_id'] != null) {
          // Create chat room for this request-shop pair
          await Supabase.instance.client.from('request_chats').insert({
            'request_id': requestId,
            'shop_id': shop['id'],
            'shop_owner_id': shop['owner_id'],
            'status': 'pending', // pending, quoted, accepted, rejected, completed
          });
          
          // Create notification for shop
          // Note: Requires RLS policy to allow authenticated users to insert notifications
          try {
            await Supabase.instance.client.from('notifications').insert({
              'user_id': shop['owner_id'],
              'title': 'New Part Request',
              'body': 'Request for $partNames - $vehicleInfo',
              'type': 'new_request',
              'reference_id': requestId,
            });
          } catch (notificationError) {
            // Don't fail the whole request if notification fails
            debugPrint('⚠️ Notification failed for shop ${shop['name']}: $notificationError');
          }
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Failed to notify shops: $e');
      return false;
    }
  }
  
  Future<String?> _getMechanicCity() async {
    try {
      final storageService = ref.read(storageServiceProvider);
      final mechanicId = await storageService.getUserId();
      final response = await Supabase.instance.client
          .from('profiles')
          .select('city')
          .eq('id', mechanicId!)
          .single();
      return response['city'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getMechanicSuburb() async {
    try {
      final storageService = ref.read(storageServiceProvider);
      final mechanicId = await storageService.getUserId();
      final response = await Supabase.instance.client
          .from('profiles')
          .select('suburb')
          .eq('id', mechanicId!)
          .single();
      return response['suburb'] as String?;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Request a Part', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: _currentStep == 0 ? _buildVehicleStep() : _buildPartsStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStepDot(0, 'Vehicle'),
          Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppTheme.accentGreen : Colors.grey[800])),
          _buildStepDot(1, 'Parts'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accentGreen : Colors.grey[800],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const Icon(LucideIcons.check, color: Colors.white, size: 18)
                : Text('${step + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.grey)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildVehicleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vehicle Details', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Select your vehicle to find the right parts', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 16),
          
          // Saved Vehicles Quick Select
          if (_savedVehicles.isNotEmpty) ...[
            const Text('My Saved Vehicles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _savedVehicles.length,
                itemBuilder: (ctx, i) {
                  final v = _savedVehicles[i];
                  final isSelected = _selectedMakeId == v.makeId && _selectedModelId == v.modelId && _selectedYear == v.year;
                  return GestureDetector(
                    onTap: () => _selectSavedVehicle(v),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentGreen.withOpacity(0.2) : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppTheme.accentGreen : Colors.grey[800]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.car, size: 14, color: isSelected ? AppTheme.accentGreen : Colors.grey),
                              if (v.isDefault) ...[
                                const SizedBox(width: 4),
                                const Icon(LucideIcons.star, size: 12, color: Colors.amber),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v.nickname ?? '${v.year} ${v.makeName}',
                            style: TextStyle(color: isSelected ? AppTheme.accentGreen : Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            v.modelName,
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),
          ],
          
          // VIN Decoder Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.scanLine, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Quick Fill with VIN', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _vinController,
                        style: const TextStyle(color: Colors.white, letterSpacing: 1),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 17,
                        decoration: InputDecoration(
                          hintText: 'Enter 17-digit VIN',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isDecodingVin ? null : _decodeVin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isDecodingVin
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Decode'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Vehicle Make
          _buildDropdownField(
            label: 'Vehicle Make *',
            hint: 'Select make',
            value: _selectedMakeId,
            items: _vehicleMakes.map((m) => DropdownMenuItem(
              value: m['id'] as String,
              child: Text(m['name'] as String),
            )).toList(),
            onChanged: (value) {
              final make = _vehicleMakes.firstWhere((m) => m['id'] == value);
              setState(() {
                _selectedMakeId = value;
                _selectedMakeName = make['name'] as String;
                _selectedModelId = null;
                _selectedModelName = null;
                _vehicleModels = [];
              });
              _loadVehicleModels(value!);
            },
          ),
          const SizedBox(height: 16),
          
          // Vehicle Model
          _buildDropdownField(
            label: 'Vehicle Model *',
            hint: _selectedMakeId == null ? 'Select make first' : 'Select model',
            value: _selectedModelId,
            items: _vehicleModels.map((m) => DropdownMenuItem(
              value: m['id'] as String,
              child: Text(m['name'] as String),
            )).toList(),
            onChanged: _selectedMakeId == null ? null : (value) {
              final model = _vehicleModels.firstWhere((m) => m['id'] == value);
              setState(() {
                _selectedModelId = value;
                _selectedModelName = model['name'] as String;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Year
          _buildDropdownField(
            label: 'Year *',
            hint: 'Select year',
            value: _selectedYear,
            items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
            onChanged: (value) => setState(() => _selectedYear = value),
          ),
          const SizedBox(height: 16),
          
          // Engine Code
          _buildTextField(
            label: 'Engine Code (Optional)',
            hint: 'e.g., CBFA, N54',
            controller: _engineCodeController,
            icon: LucideIcons.cog,
          ),
          const SizedBox(height: 24),
          
          // Save Vehicle Button
          if (_canProceedToStep2())
            TextButton.icon(
              onPressed: _saveCurrentVehicle,
              icon: const Icon(LucideIcons.bookmark, size: 18),
              label: const Text('Save this vehicle for later'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentGreen),
            ),
          const SizedBox(height: 16),
          
          // Next Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canProceedToStep2() ? () => setState(() => _currentStep = 1) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue to Parts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceedToStep2() {
    return _selectedMakeId != null && _selectedModelId != null && _selectedYear != null;
  }

  Widget _buildPartsStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back to vehicle
                TextButton.icon(
                  onPressed: () => setState(() => _currentStep = 0),
                  icon: const Icon(LucideIcons.arrowLeft, size: 18),
                  label: Text('$_selectedYear $_selectedMakeName $_selectedModelName'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accentGreen),
                ),
                const SizedBox(height: 16),
                
                const Text('Select Parts', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Add the parts you need', style: TextStyle(color: Colors.grey[400])),
                const SizedBox(height: 20),
                
                // Part Number Search
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.hash, color: Colors.purple, size: 20),
                          SizedBox(width: 8),
                          Text('Search by Part Number', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _partNumberController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'OEM or aftermarket part #',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: const Color(0xFF1E1E1E),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                              onSubmitted: (_) => _searchByPartNumber(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _searchByPartNumber,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Search'),
                            ),
                          ),
                        ],
                      ),
                      if (_partNumberResults.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...(_partNumberResults.take(3).map((p) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(p['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Text('OEM: ${p['oem_number'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.plus, color: Colors.purple, size: 20),
                            onPressed: () => _addPart(p['id'] as String, p['name'] as String),
                          ),
                        ))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Category Dropdown
                _buildDropdownField(
                  label: 'Part Category',
                  hint: 'Select category',
                  value: _selectedCategoryId,
                  items: _partCategories.map((c) => DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text(c['name'] as String),
                  )).toList(),
                  onChanged: (value) {
                    final cat = _partCategories.firstWhere((c) => c['id'] == value);
                    setState(() {
                      _selectedCategoryId = value;
                      _selectedCategoryName = cat['name'] as String;
                      _parts = [];
                    });
                    _loadParts(value!);
                  },
                ),
                const SizedBox(height: 16),
                
                // Parts Dropdown
                if (_selectedCategoryId != null) ...[
                  _buildDropdownField(
                    label: 'Part',
                    hint: 'Select part to add',
                    value: null,
                    items: _parts.map((p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['name'] as String),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final part = _parts.firstWhere((p) => p['id'] == value);
                        _addPart(value, part['name'] as String);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Selected Parts List
                if (_selectedParts.isNotEmpty) ...[
                  const Text('Added Parts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ..._selectedParts.asMap().entries.map((entry) => _buildPartItem(entry.key, entry.value)),
                  const SizedBox(height: 24),
                ],
                
                // Urgency Level
                const Text('Urgency Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildUrgencyChip('urgent', 'Urgent', 'Need today', Colors.red),
                    const SizedBox(width: 8),
                    _buildUrgencyChip('normal', 'Normal', '2-3 days', Colors.orange),
                    const SizedBox(width: 8),
                    _buildUrgencyChip('flexible', 'Flexible', 'Can wait', Colors.green),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Budget Range
                const Text('Budget Range (Optional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Min R',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixText: 'R ',
                          prefixStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)),
                        ),
                        onChanged: (v) => _budgetMin = double.tryParse(v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('to', style: TextStyle(color: Colors.grey[500])),
                    ),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Max R',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixText: 'R ',
                          prefixStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)),
                        ),
                        onChanged: (v) => _budgetMax = double.tryParse(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Additional Notes
                const Text('Additional Notes (Optional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Any specific requirements, conditions, etc.',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[800]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[800]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentGreen)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        
        // Submit Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            border: Border(top: BorderSide(color: Colors.grey[800]!)),
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedParts.isEmpty || _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Submit Request (${_selectedParts.length} ${_selectedParts.length == 1 ? "part" : "parts"})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildUrgencyChip(String value, String label, String subtitle, Color color) {
    final isSelected = _urgencyLevel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgencyLevel = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey[800]!),
          ),
          child: Column(
            children: [
              Icon(
                value == 'urgent' ? LucideIcons.zap : value == 'normal' ? LucideIcons.clock : LucideIcons.calendar,
                color: isSelected ? color : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? color : Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartItem(int index, Map<String, dynamic> part) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          // Camera icon for photo
          GestureDetector(
            onTap: () => _takePartPhoto(index),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: part['image_url'] != null ? AppTheme.accentGreen.withOpacity(0.2) : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                part['image_url'] != null ? LucideIcons.check : LucideIcons.camera,
                color: part['image_url'] != null ? AppTheme.accentGreen : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Part info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part['part_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(part['category_name'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          
          // Quantity
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.minus, size: 16),
                  onPressed: part['quantity'] > 1 ? () => _updatePartQuantity(index, part['quantity'] - 1) : null,
                  color: Colors.white,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                Text('${part['quantity']}', style: const TextStyle(color: Colors.white)),
                IconButton(
                  icon: const Icon(LucideIcons.plus, size: 16),
                  onPressed: () => _updatePartQuantity(index, part['quantity'] + 1),
                  color: Colors.white,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Remove
          IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.red, size: 20),
            onPressed: () => _removePart(index),
          ),
        ],
      ),
    );
  }

  Future<void> _takePartPhoto(int index) async {
    // Navigate to camera screen and get the photo URL back
    final result = await context.push<String>('/camera/part');
    
    if (result != null && mounted) {
      setState(() {
        _selectedParts[index]['image_url'] = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo added successfully!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(hint, style: TextStyle(color: Colors.grey[600])),
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(LucideIcons.chevronDown, color: Colors.grey),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accentGreen),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/photon_places_service.dart';
import '../../core/theme/app_theme.dart';

/// Address Autocomplete Widget using Photon API (OpenStreetMap)
/// Extracts and locks suburb/city from verified address data
/// Uses Autocomplete widget for proper overlay positioning
class AddressAutocomplete extends StatefulWidget {
  final Function(PlaceDetails) onPlaceSelected;
  final String? initialAddress;
  final String label;
  final String hint;
  
  const AddressAutocomplete({
    super.key,
    required this.onPlaceSelected,
    this.initialAddress,
    this.label = 'Search Address',
    this.hint = 'Start typing your address...',
  });

  @override
  State<AddressAutocomplete> createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<AddressAutocomplete> {
  final _controller = TextEditingController();
  final _layerLink = LayerLink();
  final _focusNode = FocusNode();
  
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  bool _showManualEntryOption = false;  // Show when no results found
  String _lastSearchQuery = '';  // Track what user searched for
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _controller.text = widget.initialAddress!;
    }
    _focusNode.addListener(_onFocusChange);
  }
  
  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  
  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay hiding to allow tap on prediction
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _removeOverlay();
        }
      });
    }
  }
  
  void _onSearchChanged(String query) {
    debugPrint('⌨️ AddressAutocomplete: Text changed to "$query"');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPlaces(query);
    });
  }
  
  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      _removeOverlay();
      setState(() {
        _predictions = [];
        _showManualEntryOption = false;
      });
      return;
    }
    
    setState(() => _isLoading = true);
    _lastSearchQuery = query;
    
    debugPrint('🔎 AddressAutocomplete: Triggering search for "$query"');
    final predictions = await PhotonPlacesService.searchPlaces(query);
    debugPrint('📋 AddressAutocomplete: Received ${predictions.length} predictions');
    
    if (mounted) {
      setState(() {
        _predictions = predictions;
        _isLoading = false;
        // Show manual entry option when no results found
        _showManualEntryOption = predictions.isEmpty;
      });
      
      // Always show overlay - either with results or manual entry option
      if (predictions.isNotEmpty || _showManualEntryOption) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
      
      if (predictions.isEmpty) {
        debugPrint('⚠️ AddressAutocomplete: No results found for "$query" - showing manual entry option');
      }
    }
  }
  
  void _showOverlay() {
    _removeOverlay();
    
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    
    if (renderBox == null) return;
    
    final size = renderBox.size;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _predictions.length + (_showManualEntryOption ? 1 : 0),
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.grey[800],
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    // Manual entry option at the end (or only item if no results)
                    if (index == _predictions.length && _showManualEntryOption) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          LucideIcons.penLine,
                          color: Colors.orange,
                          size: 20,
                        ),
                        title: const Text(
                          'Enter address manually',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          _predictions.isEmpty 
                              ? 'Address not found in database'
                              : 'Can\'t find your address?',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        onTap: _openManualEntryDialog,
                      );
                    }
                    
                    final prediction = _predictions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        prediction.isFromLocalRegistry 
                            ? LucideIcons.mapPinned 
                            : LucideIcons.mapPin,
                        color: prediction.isFromLocalRegistry 
                            ? Colors.blue 
                            : AppTheme.accentGreen,
                        size: 20,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              prediction.mainText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (prediction.isFromLocalRegistry)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Local',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        prediction.secondaryText,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectPlace(prediction),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(_overlayEntry!);
    debugPrint('✅ Overlay inserted with ${_predictions.length} items');
  }
  
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
  
  Future<void> _selectPlace(PlacePrediction prediction) async {
    debugPrint('👆 Selected: ${prediction.mainText}');
    _removeOverlay();
    
    setState(() {
      _isLoading = true;
      _predictions = [];
    });
    
    // Increment use count if from local registry
    if (prediction.isFromLocalRegistry && prediction.localRegistryId != null) {
      PhotonPlacesService.incrementAddressUseCount(prediction.localRegistryId!);
    }
    
    // Convert the prediction to details (works for both Photon and local registry)
    final details = prediction.toPlaceDetails();
    
    if (mounted) {
      debugPrint('✅ Got details - Suburb: ${details.suburb}, City: ${details.city}');
      setState(() {
        _controller.text = details.formattedAddress;
        _isLoading = false;
      });
      widget.onPlaceSelected(details);
    }
  }
  
  /// Open manual address entry dialog when address not found in Photon
  void _openManualEntryDialog() {
    debugPrint('📝 Opening manual address entry dialog');
    _removeOverlay();
    
    showDialog<PlaceDetails>(
      context: context,
      builder: (context) => ManualAddressEntryDialog(
        initialStreetAddress: _lastSearchQuery,
      ),
    ).then((details) async {
      if (details != null && mounted) {
        debugPrint('✅ Manual entry complete - Suburb: ${details.suburb}, City: ${details.city}');
        
        // Save to Sparelink Local Address Registry for future searches
        await PhotonPlacesService.saveToLocalRegistry(details);
        
        setState(() {
          _controller.text = details.formattedAddress;
          _predictions = [];
          _showManualEntryOption = false;
        });
        widget.onPlaceSelected(details);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        // Search Field with LayerLink for overlay positioning
        CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focusNode.hasFocus 
                    ? AppTheme.accentGreen 
                    : Colors.grey[800]!,
              ),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(
                  LucideIcons.mapPin,
                  color: _isLoading ? AppTheme.accentGreen : Colors.grey,
                ),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      )
                    : _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, color: Colors.grey),
                            onPressed: () {
                              _controller.clear();
                              _removeOverlay();
                              setState(() {
                                _predictions = [];
                              });
                            },
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget to display the extracted suburb and city (locked/read-only)
class ExtractedLocationDisplay extends StatelessWidget {
  final String? suburb;
  final String? city;
  final bool isVerified;
  
  const ExtractedLocationDisplay({
    super.key,
    this.suburb,
    this.city,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    if (suburb == null && city == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified 
            ? AppTheme.accentGreen.withValues(alpha: 0.1) 
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? AppTheme.accentGreen : Colors.grey[800]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified ? LucideIcons.shieldCheck : LucideIcons.mapPinned,
                color: isVerified ? AppTheme.accentGreen : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isVerified ? 'Verified Location' : 'Extracted Location',
                style: TextStyle(
                  color: isVerified ? AppTheme.accentGreen : Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (isVerified) ...[
                const Spacer(),
                Icon(
                  LucideIcons.lock,
                  color: Colors.grey[600],
                  size: 14,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Suburb
          if (suburb != null) ...[
            _buildLocationRow('Suburb', suburb!),
            const SizedBox(height: 8),
          ],
          
          // City
          if (city != null)
            _buildLocationRow('City', city!),
        ],
      ),
    );
  }
  
  Widget _buildLocationRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Manual Address Entry Dialog
/// Allows users to enter address details when Photon search returns no results
/// Returns a PlaceDetails object with the same schema as Photon results
class ManualAddressEntryDialog extends StatefulWidget {
  final String? initialStreetAddress;
  
  const ManualAddressEntryDialog({
    super.key,
    this.initialStreetAddress,
  });

  @override
  State<ManualAddressEntryDialog> createState() => _ManualAddressEntryDialogState();
}

class _ManualAddressEntryDialogState extends State<ManualAddressEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final _streetAddressController = TextEditingController();
  final _suburbController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  // South African provinces for dropdown
  static const List<String> _saProvinces = [
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];
  
  String? _selectedProvince;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialStreetAddress != null) {
      _streetAddressController.text = widget.initialStreetAddress!;
    }
  }
  
  @override
  void dispose() {
    _streetAddressController.dispose();
    _suburbController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }
  
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Build formatted address
      final addressParts = <String>[];
      if (_streetAddressController.text.isNotEmpty) {
        addressParts.add(_streetAddressController.text.trim());
      }
      if (_suburbController.text.isNotEmpty) {
        addressParts.add(_suburbController.text.trim());
      }
      if (_cityController.text.isNotEmpty) {
        addressParts.add(_cityController.text.trim());
      }
      if (_selectedProvince != null) {
        addressParts.add(_selectedProvince!);
      }
      if (_postalCodeController.text.isNotEmpty) {
        addressParts.add(_postalCodeController.text.trim());
      }
      addressParts.add('South Africa');
      
      final formattedAddress = addressParts.join(', ');
      
      // Create PlaceDetails with same schema as Photon results
      final details = PlaceDetails(
        formattedAddress: formattedAddress,
        streetNumber: null,  // Could parse from street address if needed
        streetName: _streetAddressController.text.trim(),
        suburb: _suburbController.text.isNotEmpty ? _suburbController.text.trim() : null,
        city: _cityController.text.isNotEmpty ? _cityController.text.trim() : null,
        province: _selectedProvince,
        postalCode: _postalCodeController.text.isNotEmpty ? _postalCodeController.text.trim() : null,
        latitude: null,  // No coordinates for manual entry
        longitude: null,
        country: 'South Africa',
      );
      
      debugPrint('📝 Manual entry created: ${details.formattedAddress}');
      Navigator.of(context).pop(details);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[800]!),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.penLine,
                        color: Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Enter Address Manually',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your address wasn\'t found. Please enter the details below.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  
                  // Street Address (required)
                  _buildTextField(
                    controller: _streetAddressController,
                    label: 'Street Address *',
                    hint: 'e.g., 123 Main Street',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Street address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Suburb (required)
                  _buildTextField(
                    controller: _suburbController,
                    label: 'Suburb *',
                    hint: 'e.g., Sandton',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Suburb is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // City (required)
                  _buildTextField(
                    controller: _cityController,
                    label: 'City *',
                    hint: 'e.g., Johannesburg',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'City is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Province dropdown (required)
                  _buildProvinceDropdown(),
                  const SizedBox(height: 16),
                  
                  // Postal Code (optional)
                  _buildTextField(
                    controller: _postalCodeController,
                    label: 'Postal Code',
                    hint: 'e.g., 2196',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm Address',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.accentGreen),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
  
  Widget _buildProvinceDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Province *',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedProvince,
          validator: (value) {
            if (value == null) {
              return 'Province is required';
            }
            return null;
          },
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Select province',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.accentGreen),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: _saProvinces.map((province) {
            return DropdownMenuItem<String>(
              value: province,
              child: Text(province),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedProvince = value;
            });
          },
        ),
      ],
    );
  }
}

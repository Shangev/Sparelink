import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/services/photon_places_service.dart';
import '../../../shared/widgets/address_autocomplete.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _suburbController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _provinceController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _userPhone;
  String? _userRole;
  String? _userId;
  
  // Google Places verified address data
  PlaceDetails? _selectedPlace;
  bool _addressVerified = false;
  String? _fullAddress;
  
  void _onPlaceSelected(PlaceDetails details) {
    setState(() {
      _selectedPlace = details;
      _fullAddress = details.formattedAddress;
      // Auto-populate fields from Google Places (locked data)
      _streetAddressController.text = details.streetAddress;
      _suburbController.text = details.suburb ?? '';
      _cityController.text = details.city ?? '';
      _postalCodeController.text = details.postalCode ?? '';
      _provinceController.text = details.province ?? '';
      _addressVerified = details.suburb != null || details.city != null;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _suburbController.dispose();
    _streetAddressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    final storageService = ref.read(storageServiceProvider);
    final supabaseService = ref.read(supabaseServiceProvider);
    
    final name = await storageService.getUserName();
    final phone = await storageService.getUserPhone();
    final role = await storageService.getUserRole();
    final userId = await storageService.getUserId();
    
    // Load address from Supabase
    if (userId != null) {
      final profile = await supabaseService.getProfile(userId);
      if (profile != null && mounted) {
        _suburbController.text = profile['suburb'] ?? '';
        _streetAddressController.text = profile['street_address'] ?? '';
        _cityController.text = profile['city'] ?? '';
        _postalCodeController.text = profile['postal_code'] ?? '';
        _provinceController.text = profile['province'] ?? '';
      }
    }
    
    if (mounted) {
      setState(() {
        _nameController.text = name ?? '';
        _userPhone = phone;
        _userRole = role;
        _userId = userId;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      
      final newName = _nameController.text.trim();
      final suburb = _suburbController.text.trim();
      final streetAddress = _streetAddressController.text.trim();
      final city = _cityController.text.trim();
      final postalCode = _postalCodeController.text.trim();
      final province = _provinceController.text.trim();
      
      // Update in Supabase
      if (_userId != null) {
        await supabaseService.updateProfile(
          userId: _userId!,
          fullName: newName,
          suburb: suburb.isNotEmpty ? suburb : null,
          streetAddress: streetAddress.isNotEmpty ? streetAddress : null,
          city: city.isNotEmpty ? city : null,
          postalCode: postalCode.isNotEmpty ? postalCode : null,
          province: province.isNotEmpty ? province : null,
        );
      }
      
      // Update local storage
      await storageService.saveUserName(newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF2C2C2C), Color(0xFF000000)],
              ),
            ),
          ),
          
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          if (!isDesktop)
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
                              ),
                            ),
                          if (!isDesktop) const SizedBox(width: 16),
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                
                                // Profile Avatar with Edit Button
                                Center(
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.accentGreen.withOpacity(0.2),
                                          border: Border.all(
                                            color: AppTheme.accentGreen,
                                            width: 3,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _nameController.text.isNotEmpty 
                                                ? _nameController.text[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: AppTheme.accentGreen,
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentGreen,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF121212), width: 2),
                                          ),
                                          child: const Icon(LucideIcons.camera, color: Colors.black, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 40),
                                
                                // Name Field
                                _buildGlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Full Name',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _nameController,
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                        decoration: InputDecoration(
                                          hintText: 'Enter your name',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                          prefixIcon: const Icon(LucideIcons.user, color: AppTheme.accentGreen),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.05),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: AppTheme.accentGreen),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter your name';
                                          }
                                          return null;
                                        },
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Phone (Read Only)
                                _buildGlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Phone Number',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Cannot change',
                                              style: TextStyle(color: Colors.orange, fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(LucideIcons.phone, color: Colors.grey, size: 20),
                                            const SizedBox(width: 12),
                                            Text(
                                              _userPhone ?? 'Not set',
                                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Role (Read Only)
                                _buildGlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Account Type',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Contact support to change',
                                                style: TextStyle(color: Colors.orange, fontSize: 10),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(LucideIcons.briefcase, color: Colors.grey, size: 20),
                                            const SizedBox(width: 12),
                                            Text(
                                              _userRole?.toUpperCase() ?? 'USER',
                                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 30),
                                
                                // Address Section Header
                                Row(
                                  children: [
                                    const Icon(LucideIcons.mapPin, color: AppTheme.accentGreen, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Physical Address',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Required for finding nearby shops',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Google Places Address Search
                                _buildGlassCard(
                                  child: AddressAutocomplete(
                                    label: 'Search Your Address',
                                    hint: 'Start typing your address...',
                                    initialAddress: _fullAddress,
                                    onPlaceSelected: _onPlaceSelected,
                                  ),
                                ),
                                
                                // Verified Location Display
                                if (_addressVerified) ...[
                                  const SizedBox(height: 16),
                                  ExtractedLocationDisplay(
                                    suburb: _suburbController.text,
                                    city: _cityController.text,
                                    isVerified: true,
                                  ),
                                ],
                                
                                const SizedBox(height: 16),
                                
                                // Street Address (editable but pre-filled from Google)
                                _buildGlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Street Address',
                                        style: TextStyle(color: Colors.grey, fontSize: 14),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _streetAddressController,
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 123 Main Road',
                                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                          prefixIcon: const Icon(LucideIcons.building, color: AppTheme.accentGreen),
                                          filled: true,
                                          fillColor: Colors.white.withValues(alpha: 0.05),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: AppTheme.accentGreen),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Suburb (LOCKED - from Google Places)
                                _buildGlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Suburb *',
                                            style: TextStyle(color: Colors.grey, fontSize: 14),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentGreen.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (_addressVerified)
                                                  const Icon(LucideIcons.lock, color: AppTheme.accentGreen, size: 10),
                                                if (_addressVerified)
                                                  const SizedBox(width: 4),
                                                Text(
                                                  _addressVerified ? 'Verified' : 'Used for matching',
                                                  style: const TextStyle(color: AppTheme.accentGreen, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _suburbController,
                                        readOnly: _addressVerified, // Lock if verified
                                        style: TextStyle(
                                          color: _addressVerified ? Colors.grey[400] : Colors.white,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Select address above to auto-fill',
                                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                          prefixIcon: Icon(
                                            _addressVerified ? LucideIcons.shieldCheck : LucideIcons.mapPin,
                                            color: AppTheme.accentGreen,
                                          ),
                                          suffixIcon: _addressVerified
                                              ? const Icon(LucideIcons.lock, color: Colors.grey, size: 16)
                                              : null,
                                          filled: true,
                                          fillColor: Colors.white.withValues(alpha: 0.05),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: AppTheme.accentGreen),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please select your address to fill suburb';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // City and Postal Code Row
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildGlassCard(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text(
                                                  'City',
                                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                                ),
                                                if (_addressVerified) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(LucideIcons.lock, color: Colors.grey, size: 12),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _cityController,
                                              readOnly: _addressVerified, // Lock if verified
                                              style: TextStyle(
                                                color: _addressVerified ? Colors.grey[400] : Colors.white,
                                                fontSize: 16,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'e.g. Johannesburg',
                                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                                filled: true,
                                                fillColor: Colors.white.withValues(alpha: 0.05),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: AppTheme.accentGreen),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildGlassCard(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Postal Code',
                                              style: TextStyle(color: Colors.grey, fontSize: 14),
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _postalCodeController,
                                              style: const TextStyle(color: Colors.white, fontSize: 16),
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                hintText: '2000',
                                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(0.05),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: AppTheme.accentGreen),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Province
                                _buildGlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Province',
                                        style: TextStyle(color: Colors.grey, fontSize: 14),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _provinceController,
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. Gauteng',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                          prefixIcon: const Icon(LucideIcons.map, color: AppTheme.accentGreen),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.05),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: AppTheme.accentGreen),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 40),
                                
                                // Save Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentGreen,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Save Changes',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

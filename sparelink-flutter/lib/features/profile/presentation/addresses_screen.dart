import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/settings_service.dart';
import '../../../shared/widgets/responsive_page_layout.dart';

/// Addresses Screen - Manage multiple delivery/shop addresses
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);
    final addresses = settings.savedAddresses;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return ResponsivePageLayout(
      maxWidth: ResponsivePageLayout.mediumWidth,
      title: 'My Addresses',
      showBackButton: !isDesktop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Add Address Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddressDialog(settings),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add New Address'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentGreen,
                side: const BorderSide(color: AppTheme.accentGreen),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Address List
          if (addresses.isEmpty)
            _buildEmptyState()
          else
            ...addresses.map((address) => _buildAddressCard(address, settings)),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.mapPin, color: Colors.grey[600], size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Saved Addresses',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your delivery or shop addresses for faster checkout',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(SavedAddress address, SettingsService settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: address.isDefault 
                    ? AppTheme.accentGreen.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: address.isDefault ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getTypeColor(address.type).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getTypeIcon(address.type),
                        color: _getTypeColor(address.type),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                address.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (address.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      color: AppTheme.accentGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            address.type.name.toUpperCase(),
                            style: TextStyle(
                              color: _getTypeColor(address.type),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(LucideIcons.ellipsisVertical, color: Colors.grey, size: 20),
                      color: const Color(0xFF2A2A2A),
                      onSelected: (value) => _handleMenuAction(value, address, settings),
                      itemBuilder: (context) => [
                        if (!address.isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Row(
                              children: [
                                Icon(LucideIcons.star, size: 16, color: Colors.amber),
                                SizedBox(width: 12),
                                Text('Set as Default', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(LucideIcons.pencil, size: 16, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Edit', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Address Details
                Text(
                  address.fullAddress,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.4),
                ),
                
                if (address.notes != null && address.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(LucideIcons.stickyNote, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address.notes!,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, SavedAddress address, SettingsService settings) {
    switch (action) {
      case 'default':
        settings.setDefaultAddress(address.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${address.label} set as default'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        break;
      case 'edit':
        _showAddressDialog(settings, existingAddress: address);
        break;
      case 'delete':
        _confirmDelete(address, settings);
        break;
    }
  }

  void _confirmDelete(SavedAddress address, SettingsService settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${address.label}"?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              settings.deleteAddress(address.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Address deleted'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(AddressType type) {
    switch (type) {
      case AddressType.home:
        return LucideIcons.house;
      case AddressType.work:
        return LucideIcons.briefcase;
      case AddressType.shop:
        return LucideIcons.store;
      case AddressType.delivery:
        return LucideIcons.truck;
      case AddressType.other:
        return LucideIcons.mapPin;
    }
  }

  Color _getTypeColor(AddressType type) {
    switch (type) {
      case AddressType.home:
        return Colors.blue;
      case AddressType.work:
        return Colors.orange;
      case AddressType.shop:
        return AppTheme.accentGreen;
      case AddressType.delivery:
        return Colors.purple;
      case AddressType.other:
        return Colors.grey;
    }
  }

  void _showAddressDialog(SettingsService settings, {SavedAddress? existingAddress}) {
    final isEditing = existingAddress != null;
    final labelController = TextEditingController(text: existingAddress?.label ?? '');
    final streetController = TextEditingController(text: existingAddress?.streetAddress ?? '');
    final buildingController = TextEditingController(text: existingAddress?.building ?? '');
    final suburbController = TextEditingController(text: existingAddress?.suburb ?? '');
    final cityController = TextEditingController(text: existingAddress?.city ?? '');
    final provinceController = TextEditingController(text: existingAddress?.province ?? '');
    final postalController = TextEditingController(text: existingAddress?.postalCode ?? '');
    final notesController = TextEditingController(text: existingAddress?.notes ?? '');
    
    AddressType selectedType = existingAddress?.type ?? AddressType.home;
    bool isDefault = existingAddress?.isDefault ?? false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Address' : 'Add New Address',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                // Address Type Selector
                const Text('Address Type', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AddressType.values.map((type) {
                    final isSelected = selectedType == type;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _getTypeColor(type).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? _getTypeColor(type) : Colors.grey[700]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getTypeIcon(type), size: 16, color: isSelected ? _getTypeColor(type) : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              type.name[0].toUpperCase() + type.name.substring(1),
                              style: TextStyle(
                                color: isSelected ? _getTypeColor(type) : Colors.grey,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                
                // Label
                _buildTextField(labelController, 'Label *', 'e.g., Home, Workshop, Client Site'),
                
                // Street Address
                _buildTextField(streetController, 'Street Address *', 'e.g., 123 Main Road'),
                
                // Building (Optional)
                _buildTextField(buildingController, 'Building/Unit (Optional)', 'e.g., Unit 5, Block A'),
                
                // Suburb & City Row
                Row(
                  children: [
                    Expanded(child: _buildTextField(suburbController, 'Suburb *', 'e.g., Sandton')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(cityController, 'City *', 'e.g., Johannesburg')),
                  ],
                ),
                
                // Province & Postal Code Row
                Row(
                  children: [
                    Expanded(child: _buildTextField(provinceController, 'Province *', 'e.g., Gauteng')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(postalController, 'Postal Code *', 'e.g., 2196')),
                  ],
                ),
                
                // Notes
                _buildTextField(notesController, 'Delivery Notes (Optional)', 'e.g., Gate code: 1234'),
                
                // Set as Default
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: isDefault,
                      onChanged: (value) => setSheetState(() => isDefault = value ?? false),
                      activeColor: AppTheme.accentGreen,
                    ),
                    const Text('Set as default address', style: TextStyle(color: Colors.white)),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _saveAddress(
                          ctx,
                          settings,
                          existingAddress: existingAddress,
                          label: labelController.text,
                          type: selectedType,
                          streetAddress: streetController.text,
                          building: buildingController.text,
                          suburb: suburbController.text,
                          city: cityController.text,
                          province: provinceController.text,
                          postalCode: postalController.text,
                          notes: notesController.text,
                          isDefault: isDefault,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(isEditing ? 'Save Changes' : 'Add Address'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.accentGreen),
          ),
        ),
      ),
    );
  }

  void _saveAddress(
    BuildContext ctx,
    SettingsService settings, {
    SavedAddress? existingAddress,
    required String label,
    required AddressType type,
    required String streetAddress,
    required String building,
    required String suburb,
    required String city,
    required String province,
    required String postalCode,
    required String notes,
    required bool isDefault,
  }) {
    // Validation
    if (label.isEmpty || streetAddress.isEmpty || suburb.isEmpty || 
        city.isEmpty || province.isEmpty || postalCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final address = SavedAddress(
      id: existingAddress?.id ?? const Uuid().v4(),
      label: label,
      type: type,
      streetAddress: streetAddress,
      building: building.isNotEmpty ? building : null,
      suburb: suburb,
      city: city,
      province: province,
      postalCode: postalCode,
      notes: notes.isNotEmpty ? notes : null,
      isDefault: isDefault,
      createdAt: existingAddress?.createdAt ?? DateTime.now(),
    );
    
    if (existingAddress != null) {
      settings.updateAddress(existingAddress.id, address);
    } else {
      settings.addAddress(address);
    }
    
    Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existingAddress != null ? 'Address updated' : 'Address added'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }
}

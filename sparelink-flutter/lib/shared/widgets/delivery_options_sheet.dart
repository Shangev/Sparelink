import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../services/supabase_service.dart';

/// Delivery Options Bottom Sheet
/// Allows mechanics to specify delivery address and instructions when accepting a quote
class DeliveryOptionsSheet extends ConsumerStatefulWidget {
  final String? defaultAddress;
  final Function(DeliveryOptions) onConfirm;

  const DeliveryOptionsSheet({
    super.key,
    this.defaultAddress,
    required this.onConfirm,
  });

  @override
  ConsumerState<DeliveryOptionsSheet> createState() => _DeliveryOptionsSheetState();
}

class _DeliveryOptionsSheetState extends ConsumerState<DeliveryOptionsSheet> {
  final _instructionsController = TextEditingController();
  List<Map<String, dynamic>> _savedAddresses = [];
  String? _selectedAddressId;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _useDefaultAddress = true;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.defaultAddress;
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final addresses = await supabaseService.getSavedAddresses();
      setState(() {
        _savedAddresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Delivery Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose where to deliver and add any special instructions',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Delivery Address Section
            const Text(
              'Delivery Address',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Default Address Option
            _buildAddressOption(
              title: 'Default Address',
              subtitle: widget.defaultAddress ?? 'No default address set',
              isSelected: _useDefaultAddress,
              onTap: () {
                setState(() {
                  _useDefaultAddress = true;
                  _selectedAddressId = null;
                  _selectedAddress = widget.defaultAddress;
                });
              },
            ),

            // Saved Addresses
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentGreen),
                ),
              )
            else if (_savedAddresses.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Or select a saved address:',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 8),
              ..._savedAddresses.map((addr) => _buildAddressOption(
                title: addr['label'] ?? 'Saved Address',
                subtitle: addr['full_address'] ?? addr['address'] ?? '',
                isSelected: !_useDefaultAddress && _selectedAddressId == addr['id'],
                onTap: () {
                  setState(() {
                    _useDefaultAddress = false;
                    _selectedAddressId = addr['id'];
                    _selectedAddress = addr['full_address'] ?? addr['address'];
                  });
                },
              )),
            ],
            
            const SizedBox(height: 24),

            // Delivery Instructions Section
            const Text(
              'Delivery Instructions (Optional)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add notes for the driver (e.g., "Leave at workshop entrance")',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              maxLines: 3,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Gate code: 1234, Ask for John at the workshop...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accentGreen),
                ),
                counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm(DeliveryOptions(
                    address: _selectedAddress ?? widget.defaultAddress ?? '',
                    addressId: _selectedAddressId,
                    instructions: _instructionsController.text.trim().isEmpty
                        ? null
                        : _instructionsController.text.trim(),
                  ));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Delivery Options',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentGreen.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentGreen
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.mapPin,
              color: isSelected ? AppTheme.accentGreen : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(LucideIcons.circleCheck, color: AppTheme.accentGreen, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Delivery options data class
class DeliveryOptions {
  final String address;
  final String? addressId;
  final String? instructions;

  DeliveryOptions({
    required this.address,
    this.addressId,
    this.instructions,
  });
}

/// Helper function to show the delivery options sheet
Future<DeliveryOptions?> showDeliveryOptionsSheet(
  BuildContext context, {
  String? defaultAddress,
}) async {
  DeliveryOptions? result;
  
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DeliveryOptionsSheet(
      defaultAddress: defaultAddress,
      onConfirm: (options) => result = options,
    ),
  );
  
  return result;
}

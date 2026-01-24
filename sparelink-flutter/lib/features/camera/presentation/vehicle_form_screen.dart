import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/vehicle.dart';
import '../../../shared/widgets/dropdown_modal.dart';
import '../../../shared/widgets/sparelink_logo.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/storage_service.dart';

/// Vehicle Form Screen - Part 2 of Request Flow
/// Clean, professional dark mode design for mechanics
class VehicleFormScreen extends ConsumerStatefulWidget {
  final List<XFile> images;

  const VehicleFormScreen({
    super.key,
    required this.images,
  });

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  String? _selectedMakeId;
  String? _selectedModelId;
  String? _selectedYear;
  String? _selectedPartCategory;
  
  final _vinController = TextEditingController();
  final _engineController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isSubmitting = false;

  // Design constants
  // UX-01 FIX: Use AppTheme colors for consistency
  static const Color _backgroundColor = Color(0xFF000000);  // AppTheme.primaryBlack
  static const Color _cardBackground = Color(0xFF1A1A1A);   // AppTheme.darkGray
  static const Color _inputBackground = Color(0xFF2A2A2A);  // AppTheme.mediumGray
  static const Color _subtitleGray = Color(0xFF888888);     // AppTheme.lightGray
  
  @override
  void dispose() {
    _vinController.dispose();
    _engineController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  /// Show make dropdown
  Future<void> _selectMake() async {
    final makeNames = VehicleData.carMakes.map((m) => m.name).toList();
    
    final selected = await showDropdownModal(
      context: context,
      title: 'Select Make',
      options: makeNames,
      selectedValue: _selectedMakeId != null
          ? VehicleData.getMakeById(_selectedMakeId!)?.name
          : null,
    );
    
    if (selected != null) {
      final make = VehicleData.carMakes.firstWhere((m) => m.name == selected);
      setState(() {
        _selectedMakeId = make.id;
        _selectedModelId = null;
      });
    }
  }
  
  /// Show model dropdown
  Future<void> _selectModel() async {
    if (_selectedMakeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select make first')),
      );
      return;
    }
    
    final models = VehicleData.getModelsForMake(_selectedMakeId!);
    final modelNames = models.map((m) => m.name).toList();
    
    if (modelNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No models available for this make')),
      );
      return;
    }
    
    final selected = await showDropdownModal(
      context: context,
      title: 'Select Model',
      options: modelNames,
      selectedValue: _selectedModelId != null
          ? VehicleData.getModelById(_selectedModelId!)?.name
          : null,
    );
    
    if (selected != null) {
      final model = models.firstWhere((m) => m.name == selected);
      setState(() {
        _selectedModelId = model.id;
      });
    }
  }
  
  /// Show year dropdown
  Future<void> _selectYear() async {
    final years = VehicleData.years;
    
    final selected = await showDropdownModal(
      context: context,
      title: 'Select Year',
      options: years,
      selectedValue: _selectedYear,
    );
    
    if (selected != null) {
      setState(() {
        _selectedYear = selected;
      });
    }
  }
  
  /// Show part category dropdown
  Future<void> _selectPartCategory() async {
    final selected = await showDropdownModal(
      context: context,
      title: 'Part Category',
      options: VehicleData.partCategories,
      selectedValue: _selectedPartCategory,
    );
    
    if (selected != null) {
      setState(() {
        _selectedPartCategory = selected;
      });
    }
  }
  
  /// Submit request to backend
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedMakeId == null ||
        _selectedModelId == null ||
        _selectedYear == null ||
        _selectedPartCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final currentUser = supabaseService.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      // Upload images to Supabase Storage
      final List<String> imageUrls = [];
      const uuid = Uuid();
      
      for (final image in widget.images) {
        final bytes = await image.readAsBytes();
        final fileName = '${currentUser.id}/${uuid.v4()}.jpg';
        
        final publicUrl = await supabaseService.uploadPartImage(
          fileName: fileName,
          fileBytes: bytes,
          mimeType: 'image/jpeg',
        );
        
        imageUrls.add(publicUrl);
      }
      
      final make = VehicleData.getMakeById(_selectedMakeId!)!;
      final model = VehicleData.getModelById(_selectedModelId!)!;
      
      // Create request in Supabase
      final response = await supabaseService.createPartRequest(
        mechanicId: currentUser.id,
        vehicleMake: make.name,
        vehicleModel: model.name,
        vehicleYear: int.parse(_selectedYear!),
        partCategory: _selectedPartCategory!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        vin: _vinController.text.trim().isEmpty
            ? null
            : _vinController.text.trim(),
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
      );
      
      if (mounted) {
        final requestId = response['id'] as String;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request created! Searching for shops...'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        
        context.go('/marketplace/$requestId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final make = _selectedMakeId != null
        ? VehicleData.getMakeById(_selectedMakeId!)
        : null;
    final model = _selectedModelId != null
        ? VehicleData.getModelById(_selectedModelId!)
        : null;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width > 500
                  ? 500
                  : MediaQuery.of(context).size.width * 0.92,
              margin: const EdgeInsets.symmetric(vertical: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with logo and notification
                    _buildHeader(),
                    const SizedBox(height: 24),
                    
                    // Title
                    const Text(
                      'Vehicle Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your vehicle information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Image preview (if images exist)
                    if (widget.images.isNotEmpty) ...[
                      _buildImagePreview(),
                      const SizedBox(height: 24),
                    ],
                    
                    // Year dropdown
                    _buildDropdownField(
                      label: 'Year Model',
                      value: _selectedYear,
                      placeholder: 'Select Year',
                      onTap: _selectYear,
                      hasDropdown: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // Make dropdown
                    _buildDropdownField(
                      label: 'Vehicle Make',
                      value: make?.name,
                      placeholder: 'Select Make',
                      onTap: _selectMake,
                      hasDropdown: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // Model dropdown
                    _buildDropdownField(
                      label: 'Vehicle Model',
                      value: model?.name,
                      placeholder: 'Select Model',
                      onTap: _selectModel,
                      hasDropdown: true,
                      enabled: _selectedMakeId != null,
                    ),
                    const SizedBox(height: 16),
                    
                    // VIN or Engine Number
                    _buildTextField(
                      label: 'VIN or Engine Number',
                      controller: _vinController,
                      placeholder: 'Enter VIN or Engine Number',
                    ),
                    const SizedBox(height: 16),
                    
                    // Part Category dropdown
                    _buildDropdownField(
                      label: 'Part Category',
                      value: _selectedPartCategory,
                      placeholder: 'Select Part Category',
                      onTap: _selectPartCategory,
                      hasDropdown: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description (optional)
                    _buildTextField(
                      label: 'Description (Optional)',
                      controller: _descriptionController,
                      placeholder: 'Add details about the part needed',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    
                    // Submit button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button and logo
        Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  LucideIcons.arrowLeft,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const SpareLinkFullLogo(iconSize: 28),
          ],
        ),
        // Notification icon
        GestureDetector(
          onTap: () => context.push('/notifications'),
          child: const Icon(
            LucideIcons.bell,
            color: _subtitleGray,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos (${widget.images.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.images[index].path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    bool hasDropdown = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: enabled ? _inputBackground : _inputBackground.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    style: TextStyle(
                      color: value != null ? Colors.white : _subtitleGray,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (hasDropdown)
                  Icon(
                    Icons.arrow_drop_down,
                    color: enabled ? Colors.white : _subtitleGray,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _inputBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(color: _subtitleGray),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Submit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

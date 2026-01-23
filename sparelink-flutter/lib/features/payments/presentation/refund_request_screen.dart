import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/models/payment_models.dart';
import '../../../shared/services/payment_service.dart';
import '../../../shared/widgets/responsive_page_layout.dart';

/// Screen for requesting a refund on an order
class RefundRequestScreen extends ConsumerStatefulWidget {
  final String orderId;
  final Order? order;

  const RefundRequestScreen({
    super.key,
    required this.orderId,
    this.order,
  });

  @override
  ConsumerState<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends ConsumerState<RefundRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  RefundReason? _selectedReason;
  List<XFile> _photos = [];
  bool _isSubmitting = false;
  bool _agreedToTerms = false;
  Order? _order;
  RefundRequest? _existingRefund;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadOrderAndRefundStatus();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadOrderAndRefundStatus() async {
    // Load existing refund request if any
    final paymentService = ref.read(paymentServiceProvider);
    final existingRefund = await paymentService.getRefundRequest(widget.orderId);
    
    if (mounted) {
      setState(() {
        _existingRefund = existingRefund;
      });
    }
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (images.isNotEmpty) {
      setState(() {
        _photos = [..._photos, ...images].take(5).toList(); // Max 5 photos
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null && _photos.length < 5) {
      setState(() {
        _photos = [..._photos, image];
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<List<String>> _uploadPhotos() async {
    final List<String> urls = [];
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    
    if (userId == null) return urls;

    for (int i = 0; i < _photos.length; i++) {
      final photo = _photos[i];
      final bytes = await photo.readAsBytes();
      final fileName = 'refund_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final path = '$userId/refunds/$fileName';

      await supabase.storage.from('refund-photos').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final url = supabase.storage.from('refund-photos').getPublicUrl(path);
      urls.add(url);
    }

    return urls;
  }

  Future<void> _submitRefund() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the refund policy'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload photos first
      List<String> photoUrls = [];
      if (_photos.isNotEmpty) {
        photoUrls = await _uploadPhotos();
      }

      // Submit refund request
      final paymentService = ref.read(paymentServiceProvider);
      final result = await paymentService.requestRefund(
        orderId: widget.orderId,
        reason: _selectedReason!.displayName,
        description: _descriptionController.text.trim(),
        photoUrls: photoUrls.isNotEmpty ? photoUrls : null,
      );

      if (result.success) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.checkCircle,
                color: AppTheme.accentGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Refund Request Submitted',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We\'ll review your request within 2-3 business days and notify you of the outcome.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/orders');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('View Orders', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If there's already a refund request, show its status
    if (_existingRefund != null) {
      return _buildExistingRefundView();
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlack,
        title: const Text('Request Refund'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsivePageLayout(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order info card
                if (_order != null) _buildOrderCard(),
                const SizedBox(height: 24),

                // Reason selection
                _buildReasonSection(),
                const SizedBox(height: 24),

                // Description
                _buildDescriptionSection(),
                const SizedBox(height: 24),

                // Photo upload
                _buildPhotoSection(),
                const SizedBox(height: 24),

                // Refund policy agreement
                _buildPolicyAgreement(),
                const SizedBox(height: 24),

                // Submit button
                _buildSubmitButton(),
                const SizedBox(height: 16),

                // Note
                _buildNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingRefundView() {
    final refund = _existingRefund!;
    
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlack,
        title: const Text('Refund Status'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsivePageLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _getStatusIcon(refund.status),
                    const SizedBox(height: 16),
                    Text(
                      _getStatusTitle(refund.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusMessage(refund.status),
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Refund details
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Refund Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Reason', refund.reason),
                    if (refund.description != null && refund.description!.isNotEmpty)
                      _buildDetailRow('Description', refund.description!),
                    _buildDetailRow('Submitted', _formatDate(refund.createdAt)),
                    if (refund.refundAmountCents != null)
                      _buildDetailRow('Refund Amount', refund.formattedRefundAmount),
                    if (refund.adminNotes != null)
                      _buildDetailRow('Notes', refund.adminNotes!),
                  ],
                ),
              ),

              // Photos if any
              if (refund.photoUrls != null && refund.photoUrls!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attached Photos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: refund.photoUrls!.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(refund.photoUrls![index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStatusIcon(RefundStatus status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case RefundStatus.pending:
        icon = LucideIcons.clock;
        color = Colors.orange;
        break;
      case RefundStatus.approved:
        icon = LucideIcons.checkCircle;
        color = Colors.blue;
        break;
      case RefundStatus.rejected:
        icon = LucideIcons.xCircle;
        color = Colors.red;
        break;
      case RefundStatus.processed:
        icon = LucideIcons.checkCircle2;
        color = AppTheme.accentGreen;
        break;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 40),
    );
  }

  String _getStatusTitle(RefundStatus status) {
    switch (status) {
      case RefundStatus.pending:
        return 'Under Review';
      case RefundStatus.approved:
        return 'Refund Approved';
      case RefundStatus.rejected:
        return 'Refund Declined';
      case RefundStatus.processed:
        return 'Refund Completed';
    }
  }

  String _getStatusMessage(RefundStatus status) {
    switch (status) {
      case RefundStatus.pending:
        return 'Your refund request is being reviewed. We\'ll update you within 2-3 business days.';
      case RefundStatus.approved:
        return 'Your refund has been approved and will be processed shortly.';
      case RefundStatus.rejected:
        return 'Unfortunately, your refund request was not approved. Please contact support for more information.';
      case RefundStatus.processed:
        return 'Your refund has been processed. The amount will appear in your account within 5-10 business days.';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildOrderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.package, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _order?.partCategory ?? 'Order #${widget.orderId.substring(0, 8)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                if (_order?.vehicleInfo != null)
                  Text(
                    _order!.vehicleInfo!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
              ],
            ),
          ),
          Text(
            'R ${((_order?.totalCents ?? 0) / 100).toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Why are you requesting a refund?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...RefundReason.values.map((reason) => _buildReasonTile(reason)),
      ],
    );
  }

  Widget _buildReasonTile(RefundReason reason) {
    final isSelected = _selectedReason == reason;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedReason = reason),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? LucideIcons.checkCircle : LucideIcons.circle,
              color: isSelected ? AppTheme.accentGreen : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason.displayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    reason.description,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 500,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Please provide more details about the issue...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: AppTheme.cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            counterStyle: TextStyle(color: Colors.grey[400]),
          ),
          validator: (value) {
            if (_selectedReason == RefundReason.other && (value == null || value.trim().isEmpty)) {
              return 'Please describe the issue';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Add Photos (Optional)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_photos.length}/5',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Photos help us understand the issue better',
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
        const SizedBox(height: 12),
        
        // Photo grid
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add photo buttons
              if (_photos.length < 5) ...[
                _buildAddPhotoButton(
                  icon: LucideIcons.camera,
                  label: 'Camera',
                  onTap: _takePhoto,
                ),
                const SizedBox(width: 12),
                _buildAddPhotoButton(
                  icon: LucideIcons.image,
                  label: 'Gallery',
                  onTap: _pickPhotos,
                ),
                const SizedBox(width: 12),
              ],
              
              // Photo previews
              ..._photos.asMap().entries.map((entry) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(File(entry.value.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => _removePhoto(entry.key),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.x, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accentGreen, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyAgreement() {
    return GestureDetector(
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _agreedToTerms ? LucideIcons.squareCheck : LucideIcons.square,
            color: _agreedToTerms ? AppTheme.accentGreen : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                children: const [
                  TextSpan(text: 'I understand that refunds are subject to review and the '),
                  TextSpan(
                    text: 'Refund Policy',
                    style: TextStyle(color: AppTheme.accentGreen),
                  ),
                  TextSpan(text: '. False claims may result in account suspension.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRefund,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: AppTheme.accentGreen.withOpacity(0.5),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            : const Text(
                'Submit Refund Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Refunds typically take 5-10 business days to process once approved. You\'ll receive email updates on your request status.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

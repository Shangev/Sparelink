import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/models/payment_models.dart';
import '../../../shared/services/payment_service.dart';
import '../../../shared/services/haptic_service.dart';
import '../../../shared/widgets/haptic_buttons.dart';
import '../../../shared/widgets/haptic_tap.dart';
import '../../../shared/widgets/responsive_page_layout.dart';

/// Checkout screen for processing payments
class CheckoutScreen extends ConsumerStatefulWidget {
  final Order order;

  const CheckoutScreen({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isLoading = false;
  bool _saveCard = false;
  SavedCard? _selectedCard;
  List<SavedCard> _savedCards = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    final paymentService = ref.read(paymentServiceProvider);
    final cards = await paymentService.getSavedCards();
    if (mounted) {
      setState(() {
        _savedCards = cards;
        // Auto-select default card if available
        _selectedCard = cards.where((c) => c.isDefault).firstOrNull;
      });
    }
  }

  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      
      // Get user email from profile or order
      final email = widget.order.customerEmail ?? 'customer@example.com';

      final result = await paymentService.processPayment(
        context: context,
        order: widget.order,
        email: email,
        savedCard: _selectedCard,
      );

      if (result.success) {
        await HapticService.successPattern();
        // Save card if requested and we got authorization code
        if (_saveCard && 
            result.authorizationCode != null &&
            result.cardLast4 != null &&
            result.cardBrand != null) {
          await paymentService.saveCard(
            authorizationCode: result.authorizationCode!,
            email: email,
            last4: result.cardLast4!,
            brand: result.cardBrand!,
            expMonth: '12', // These would come from Paystack response
            expYear: '25',
            cardType: 'debit',
            bank: 'Unknown',
          );
        }

        if (mounted) {
          _showSuccessDialog(result);
        }
      } else {
        await HapticService.error();
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      await HapticService.error();
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(PaymentResult result) {
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
              'Payment Successful!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reference: ${result.reference}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await HapticService.light();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    context.go('/order/${widget.order.id}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Track Order',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlack,
        title: const Text('Checkout'),
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
              // Order Summary Card
              _buildOrderSummary(),
              const SizedBox(height: 24),

              // Saved Cards Section
              if (_savedCards.isNotEmpty) ...[
                _buildSavedCardsSection(),
                const SizedBox(height: 24),
              ],

              // Payment Options
              _buildPaymentOptions(),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertCircle, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Pay Button
              _buildPayButton(),
              const SizedBox(height: 16),

              // Security Note
              _buildSecurityNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Part info
          if (widget.order.partCategory != null) ...[
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.package,
                    color: AppTheme.accentGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.partCategory!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.order.vehicleInfo != null)
                        Text(
                          widget.order.vehicleInfo!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),
          ],

          // Price breakdown
          _buildPriceRow('Subtotal', widget.order.totalCents),
          const SizedBox(height: 8),
          _buildPriceRow('VAT (15%)', (widget.order.totalCents * 0.15).round(), isVat: true),
          const SizedBox(height: 8),
          _buildPriceRow('Delivery', 0, isFree: true),
          const SizedBox(height: 16),
          const Divider(color: Colors.grey),
          const SizedBox(height: 16),
          
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'R ${(widget.order.totalCents / 100).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.accentGreen,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, int cents, {bool isVat = false, bool isFree = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        Text(
          isFree ? 'FREE' : 'R ${(cents / 100).toStringAsFixed(2)}',
          style: TextStyle(
            color: isFree ? AppTheme.accentGreen : Colors.grey[300],
            fontSize: 14,
            fontWeight: isFree ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Saved Cards',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/payment-methods'),
              child: const Text(
                'Manage',
                style: TextStyle(color: AppTheme.accentGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_savedCards.map((card) => _buildSavedCardTile(card))),
      ],
    );
  }

  Widget _buildSavedCardTile(SavedCard card) {
    final isSelected = _selectedCard?.id == card.id;
    
    return HapticTap(
      onTap: () {
        setState(() {
          _selectedCard = isSelected ? null : card;
        });
      },
      haptic: HapticService.selection,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: _getCardBrandIcon(card.brand),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '**** **** **** ${card.last4}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Expires ${card.expiryDate}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (card.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? LucideIcons.checkCircle : LucideIcons.circle,
              color: isSelected ? AppTheme.accentGreen : Colors.grey,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCardBrandIcon(String brand) {
    // In a real app, use actual card brand images
    switch (brand.toLowerCase()) {
      case 'visa':
        return const Text('VISA', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10));
      case 'mastercard':
        return const Text('MC', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10));
      default:
        return const Icon(LucideIcons.creditCard, size: 20, color: Colors.grey);
    }
  }

  Widget _buildPaymentOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // New Card Option
        GestureDetector(
          onTap: () async {
            await HapticService.selection();
            setState(() {
              _selectedCard = null;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedCard == null ? AppTheme.accentGreen : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.creditCard,
                    color: AppTheme.accentGreen,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay with Card',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Visa, Mastercard, or Verve',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _selectedCard == null ? LucideIcons.checkCircle : LucideIcons.circle,
                  color: _selectedCard == null ? AppTheme.accentGreen : Colors.grey,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        
        // Save card checkbox (only for new cards)
        if (_selectedCard == null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              await HapticService.selection();
              setState(() {
                _saveCard = !_saveCard;
              });
            },
            child: Row(
              children: [
                Icon(
                  _saveCard ? LucideIcons.squareCheck : LucideIcons.square,
                  color: _saveCard ? AppTheme.accentGreen : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Save card for future purchases',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: HapticElevatedButton(
        onPressed: _isLoading ? null : () async => _processPayment(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppTheme.accentGreen.withOpacity(0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Pay R ${(widget.order.totalCents / 100).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.shield,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your payment is secured with 256-bit SSL encryption. We never store your full card details.',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

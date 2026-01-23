import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/payment_models.dart';
import '../../../shared/services/payment_service.dart';
import '../../../shared/widgets/responsive_page_layout.dart';
import '../../../shared/widgets/empty_state.dart';

/// Screen for managing saved payment methods (tokenized cards)
class SavedCardsScreen extends ConsumerStatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  ConsumerState<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends ConsumerState<SavedCardsScreen> {
  List<SavedCard> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    try {
      final paymentService = ref.read(paymentServiceProvider);
      final cards = await paymentService.getSavedCards();
      if (mounted) {
        setState(() {
          _cards = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load cards');
      }
    }
  }

  Future<void> _setDefault(SavedCard card) async {
    try {
      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.setDefaultCard(card.id);
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${card.brand} •••• ${card.last4} set as default'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to set default card');
    }
  }

  Future<void> _deleteCard(SavedCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Card', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${card.brand} •••• ${card.last4} from your saved cards?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final paymentService = ref.read(paymentServiceProvider);
        await paymentService.deleteCard(card.id);
        await _loadCards();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Card removed successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } catch (e) {
        _showError('Failed to remove card');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlack,
        title: const Text('Payment Methods'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsivePageLayout(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
            : _cards.isEmpty
                ? _buildEmptyState()
                : _buildCardsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: LucideIcons.creditCard,
      title: 'No Saved Cards',
      message: 'Cards you use for payments will appear here for faster checkout.',
      actionLabel: 'Make a Purchase',
      onAction: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildCardsList() {
    return RefreshIndicator(
      onRefresh: _loadCards,
      color: AppTheme.accentGreen,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your card details are securely stored and encrypted. We never see your full card number.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cards list
          ..._cards.map((card) => _buildCardTile(card)),
        ],
      ),
    );
  }

  Widget _buildCardTile(SavedCard card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: card.isDefault
            ? Border.all(color: AppTheme.accentGreen.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Column(
        children: [
          // Card info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Card brand icon
                Container(
                  width: 56,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(child: _getCardBrandWidget(card.brand)),
                ),
                const SizedBox(width: 16),
                
                // Card details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '•••• •••• •••• ${card.last4}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          if (card.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  color: AppTheme.accentGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${card.brand} • Expires ${card.expiryDate}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      if (card.bank.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          card.bank,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),

                // Expired badge
                if (card.isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Expired',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Actions
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                if (!card.isDefault)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _setDefault(card),
                      icon: const Icon(LucideIcons.star, size: 16),
                      label: const Text('Set Default'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accentGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                if (!card.isDefault)
                  Container(width: 1, height: 48, color: Colors.grey[800]),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _deleteCard(card),
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCardBrandWidget(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return const Text(
          'VISA',
          style: TextStyle(
            color: Color(0xFF1A1F71),
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        );
      case 'mastercard':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFFEB001B),
                shape: BoxShape.circle,
              ),
            ),
            Transform.translate(
              offset: const Offset(-6, 0),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFF79E1B).withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      case 'verve':
        return const Text(
          'Verve',
          style: TextStyle(
            color: Color(0xFF00425F),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
      default:
        return const Icon(LucideIcons.creditCard, size: 24, color: Colors.grey);
    }
  }
}

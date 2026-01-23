import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/payment_models.dart';
import '../../../shared/services/payment_service.dart';
import '../../../shared/widgets/responsive_page_layout.dart';
import '../../../shared/widgets/empty_state.dart';

/// Screen showing payment history and transaction records
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  List<PaymentTransaction> _transactions = [];
  PaymentStats? _stats;
  bool _isLoading = true;
  String _filter = 'all'; // all, success, failed, refunded

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final paymentService = ref.read(paymentServiceProvider);
      final transactions = await paymentService.getPaymentHistory(
        status: _filter == 'all' ? null : _filter,
      );
      final stats = await paymentService.getPaymentStats();
      
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlack,
        title: const Text('Payment History'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.creditCard),
            onPressed: () => context.push('/payment-methods'),
            tooltip: 'Saved Cards',
          ),
        ],
      ),
      body: ResponsivePageLayout(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accentGreen),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.accentGreen,
                child: CustomScrollView(
                  slivers: [
                    // Stats cards
                    if (_stats != null)
                      SliverToBoxAdapter(child: _buildStatsSection()),

                    // Filter chips
                    SliverToBoxAdapter(child: _buildFilterChips()),

                    // Transactions list
                    _transactions.isEmpty
                        ? SliverFillRemaining(child: _buildEmptyState())
                        : SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildTransactionTile(
                                  _transactions[index],
                                ),
                                childCount: _transactions.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGreen.withOpacity(0.2),
            AppTheme.cardDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Spent',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _stats!.formattedTotalSpent,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem(
                icon: LucideIcons.checkCircle,
                color: AppTheme.accentGreen,
                value: _stats!.successfulPayments.toString(),
                label: 'Successful',
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                icon: LucideIcons.xCircle,
                color: Colors.red,
                value: _stats!.failedPayments.toString(),
                label: 'Failed',
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                icon: LucideIcons.clock,
                color: Colors.orange,
                value: _stats!.pendingRefunds.toString(),
                label: 'Refunds',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'success', 'label': 'Successful'},
      {'key': 'failed', 'label': 'Failed'},
      {'key': 'refunded', 'label': 'Refunded'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(f['label']!),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.grey[300],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: AppTheme.cardDark,
              selectedColor: AppTheme.accentGreen,
              checkmarkColor: Colors.black,
              side: BorderSide.none,
              onSelected: (selected) {
                setState(() => _filter = f['key']!);
                _loadData();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: LucideIcons.receipt,
      title: 'No Transactions',
      message: _filter == 'all'
          ? 'Your payment history will appear here once you make a purchase.'
          : 'No ${_filter} transactions found.',
      actionLabel: _filter != 'all' ? 'View All' : null,
      onAction: _filter != 'all'
          ? () {
              setState(() => _filter = 'all');
              _loadData();
            }
          : null,
    );
  }

  Widget _buildTransactionTile(PaymentTransaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTransactionDetails(transaction),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getStatusColor(transaction.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(transaction.status),
                    color: _getStatusColor(transaction.status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Transaction info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.partName ?? 'Payment',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (transaction.shopName != null) ...[
                            Text(
                              transaction.shopName!,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                          Text(
                            _formatDate(transaction.createdAt),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      transaction.formattedAmount,
                      style: TextStyle(
                        color: transaction.status == TransactionStatus.refunded
                            ? Colors.orange
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(transaction.status)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transaction.statusDisplay,
                        style: TextStyle(
                          color: _getStatusColor(transaction.status),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
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

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return AppTheme.accentGreen;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.refunded:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return LucideIcons.checkCircle;
      case TransactionStatus.failed:
        return LucideIcons.xCircle;
      case TransactionStatus.pending:
        return LucideIcons.clock;
      case TransactionStatus.refunded:
        return LucideIcons.refreshCcw;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today, ${DateFormat.jm().format(date)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.EEEE().format(date);
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  void _showTransactionDetails(PaymentTransaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _TransactionDetailsSheet(transaction: transaction),
    );
  }
}

class _TransactionDetailsSheet extends StatelessWidget {
  final PaymentTransaction transaction;

  const _TransactionDetailsSheet({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.statusDisplay,
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      transaction.formattedAmount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Details
          _buildDetailRow('Reference', transaction.reference),
          _buildDetailRow('Date', DateFormat.yMMMMd().add_jm().format(transaction.createdAt)),
          if (transaction.paymentMethodDisplay.isNotEmpty)
            _buildDetailRow('Payment Method', transaction.paymentMethodDisplay),
          if (transaction.partName != null)
            _buildDetailRow('Item', transaction.partName!),
          if (transaction.shopName != null)
            _buildDetailRow('Shop', transaction.shopName!),
          _buildDetailRow('Order ID', transaction.orderId.substring(0, 8).toUpperCase()),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/order/${transaction.orderId}');
                  },
                  icon: const Icon(LucideIcons.package, size: 18),
                  label: const Text('View Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (transaction.status == TransactionStatus.success) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/refund/${transaction.orderId}');
                    },
                    icon: const Icon(LucideIcons.refreshCcw, size: 18),
                    label: const Text('Refund'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (transaction.status) {
      case TransactionStatus.success:
        return AppTheme.accentGreen;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.refunded:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    switch (transaction.status) {
      case TransactionStatus.success:
        return LucideIcons.checkCircle;
      case TransactionStatus.failed:
        return LucideIcons.xCircle;
      case TransactionStatus.pending:
        return LucideIcons.clock;
      case TransactionStatus.refunded:
        return LucideIcons.refreshCcw;
    }
  }
}

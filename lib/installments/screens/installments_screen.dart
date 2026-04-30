import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/app_data_store.dart';
import '../../core/db_models.dart';
import '../widgets/installment_stat_card.dart';
import '../widgets/payment_plan_card.dart';
import '../../pos/widgets/upcoming_payments_sidebar.dart';
import '../widgets/new_installment_plan_dialog.dart';
import 'record_payment_dialog.dart';

class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({Key? key}) : super(key: key);

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  final _store = AppDataStore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: ValueListenableBuilder<List<DbInstallmentPlan>>(
          valueListenable: _store.installmentsNotifier,
          builder: (context, plans, _) {
            final active    = plans.where((p) => p.status == 'active').length;
            final overdue   = plans.where((p) => p.isOverdue).length;
            final collected = plans.fold<double>(0, (s, p) => s + p.paidAmount);
            final pending   = plans.fold<double>(0, (s, p) => s + p.remainingAmount);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  _buildStatCards(active, collected, pending, overdue),
                  const SizedBox(height: 40),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main list
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Plans',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildPaymentPlanList(plans),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Sidebar
                      const Expanded(flex: 1, child: UpcomingPaymentsSidebar()),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Installments System',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Track payment plans and manage installments',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                ),
              ],
            ),
            const SizedBox(width: 24),
            TextButton.icon(
              onPressed: () => context.go('/pos'),
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('Back to POS'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const NewInstallmentPlanDialog(),
          ),
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('New Payment Plan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(int active, double collected, double pending, int overdue) {
    String fmt(double v) => v >= 1000 ? '\$${(v / 1000).toStringAsFixed(1)}K' : '\$${v.toStringAsFixed(0)}';
    return Row(
      children: [
        Expanded(
          child: InstallmentStatCard(
            title: 'Active Plans',
            value: '$active',
            icon: Icons.calendar_today_outlined,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: InstallmentStatCard(
            title: 'Total Collected',
            value: fmt(collected),
            icon: Icons.attach_money,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: InstallmentStatCard(
            title: 'Pending',
            value: fmt(pending),
            icon: Icons.error_outline,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: InstallmentStatCard(
            title: 'Overdue Plans',
            value: '$overdue',
            icon: Icons.trending_down,
            color: const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPlanList(List<DbInstallmentPlan> plans) {
    if (plans.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text(
            'No payment plans yet.\nClick "New Payment Plan" to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
          ),
        ),
      );
    }

    return Column(
      children: plans.map((plan) {
        final progress = plan.totalAmount > 0
            ? plan.paidAmount / plan.totalAmount
            : 0.0;
        return PaymentPlanCard(
          clientName: plan.clientName,
          itemName: 'Invoice #${plan.invoiceId}',
          status: plan.status,
          progress: progress.clamp(0.0, 1.0),
          totalAmount: plan.totalAmount,
          paidAmount: plan.paidAmount,
          remainingAmount: plan.remainingAmount,
          monthlyAmount: plan.monthlyInstallment,
          interestRate: plan.interestRate,
          nextPaymentDate: '—',
          onViewDetails: () => _showPaymentHistory(context, plan),
          onRecordPayment: plan.isCompleted
              ? null
              : () => showDialog(
                    context: context,
                    builder: (_) => RecordPaymentDialog(plan: plan),
                  ),
        );
      }).toList(),
    );
  }

  void _showPaymentHistory(BuildContext context, DbInstallmentPlan plan) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${plan.clientName} — Plan Summary',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Invoice #${plan.invoiceId}',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 16),
                _summaryRow('Total Amount',    '\$${plan.totalAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 10),
                _summaryRow('Paid',            '\$${plan.paidAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 10),
                _summaryRow('Remaining',       '\$${plan.remainingAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 10),
                _summaryRow('Monthly',         '\$${plan.monthlyInstallment.toStringAsFixed(2)}'),
                const SizedBox(height: 10),
                _summaryRow('Status',          plan.status),
                const SizedBox(height: 10),
                _summaryRow('Created',         plan.createdAt),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

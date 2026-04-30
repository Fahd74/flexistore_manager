import 'package:flutter/material.dart';
import '../../installments/data/app_data_store.dart';
import '../../installments/screens/record_payment_dialog.dart';
import '../../core/db_models.dart';

class UpcomingPaymentsSidebar extends StatelessWidget {
  const UpcomingPaymentsSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DbInstallmentPlan>>(
      valueListenable: AppDataStore.instance.installmentsNotifier,
      builder: (context, plans, _) {
        final upcoming = plans.where((p) => p.status != 'completed').toList()
          ..sort((a, b) {
            if (a.isOverdue && !b.isOverdue) return -1;
            if (b.isOverdue && !a.isOverdue) return 1;
            return 0;
          });

        final totalExpected  = plans.fold<double>(0, (s, p) => s + p.totalAmount);
        final totalCollected = plans.fold<double>(0, (s, p) => s + p.paidAmount);
        final totalRemaining = plans.fold<double>(0, (s, p) => s + p.remainingAmount);
        final rate = totalExpected > 0 ? totalCollected / totalExpected : 0.0;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.calendar_today_outlined, color: Color(0xFF94A3B8), size: 20),
            SizedBox(width: 8),
            Text('Upcoming Payments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 24),

          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No upcoming payments.',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13))),
            )
          else
            ...upcoming.map((p) => _buildItem(context, p)),

          const SizedBox(height: 32),

          // Monthly overview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.calendar_month, color: Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Monthly Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('All Plans', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 24),
              _overviewRow('Total',     _fmt(totalExpected),  Colors.white),
              const SizedBox(height: 12),
              _overviewRow('Collected', _fmt(totalCollected), const Color(0xFF10B981)),
              const SizedBox(height: 12),
              _overviewRow('Remaining', _fmt(totalRemaining), const Color(0xFFF59E0B)),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF334155),
                color: const Color(0xFF3B82F6),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Center(child: Text('${(rate * 100).toStringAsFixed(0)}% collection rate',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11))),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _buildItem(BuildContext context, DbInstallmentPlan plan) {
    final overdue = plan.isOverdue;
    final color   = overdue ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: overdue ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF334155)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(plan.clientName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (overdue) const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
        ]),
        const SizedBox(height: 2),
        Text('Invoice #${plan.invoiceId}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('Started: ${plan.createdAt}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('\$${plan.monthlyInstallment.toStringAsFixed(2)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ElevatedButton(
            onPressed: () => _handleBtn(context, plan, overdue),
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              minimumSize: const Size(64, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(overdue ? 'Collect' : 'Remind',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  void _handleBtn(BuildContext context, DbInstallmentPlan plan, bool overdue) {
    if (overdue) {
      showDialog(context: context, builder: (_) => RecordPaymentDialog(plan: plan));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reminder sent to ${plan.clientName} for \$${plan.monthlyInstallment.toStringAsFixed(2)}.'),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Widget _overviewRow(String label, String value, Color valueColor) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
      Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14)),
    ],
  );

  String _fmt(double v) => v >= 1000 ? '\$${(v / 1000).toStringAsFixed(1)}K' : '\$${v.toStringAsFixed(0)}';
}

import 'package:flutter/material.dart';
import '../data/app_data_store.dart';
import '../../core/db_models.dart';

class RecordPaymentDialog extends StatefulWidget {
  final DbInstallmentPlan plan;
  const RecordPaymentDialog({Key? key, required this.plan}) : super(key: key);

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _amountCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill with monthly amount as convenience
    _amountCtrl.text = widget.plan.monthlyInstallment.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount greater than 0.');
      return;
    }
    if (amount > widget.plan.remainingAmount + 0.01) {
      setState(() => _error =
          'Amount exceeds remaining balance (\$${widget.plan.remainingAmount.toStringAsFixed(2)}).');
      return;
    }

    // Using userId: 1 for now (admin)
    await AppDataStore.instance.recordPayment(
      installmentId: widget.plan.id,
      userId: 1,
      amount: amount,
    );
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Text(
          'Payment of \$${amount.toStringAsFixed(2)} recorded for ${widget.plan.clientName}.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_outlined,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Record Payment',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 16),

            // ── Client & item info ─────────────────────────────────────────
            _infoRow('Client',    plan.clientName),
            const SizedBox(height: 8),
            _infoRow('Item',      'Invoice #${plan.invoiceId}'),
            const SizedBox(height: 8),
            _infoRow('Remaining', '\$${plan.remainingAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _infoRow('Monthly',   '\$${plan.monthlyInstallment.toStringAsFixed(2)}'),
            const SizedBox(height: 24),

            // ── Amount input ───────────────────────────────────────────────
            const Text(
              'Payment Amount (\$)',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _error != null
                      ? Colors.redAccent
                      : const Color(0xFF334155),
                ),
              ),
              child: TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
              ]),
            ],
            const SizedBox(height: 28),

            // ── Actions ───────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Confirm Payment',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

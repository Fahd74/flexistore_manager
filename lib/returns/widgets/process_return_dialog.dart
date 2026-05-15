import 'package:flutter/material.dart';
import '../data/returns_ffi.dart';

/// Dialog that allows the user to select which items from an invoice to return,
/// the quantity of each, and select a reason from a dropdown.
class ProcessReturnDialog extends StatefulWidget {
  final ReturnableInvoice invoice;
  final List<String> reasons; // Added list of predefined reasons

  const ProcessReturnDialog({
    super.key,
    required this.invoice,
    required this.reasons,
  });

  @override
  State<ProcessReturnDialog> createState() => _ProcessReturnDialogState();
}

class _ProcessReturnDialogState extends State<ProcessReturnDialog> {
  // ── Theme ──────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _border = Color(0xFF334155);
  static const _textSub = Color(0xFF94A3B8);
  static const _danger = Color(0xFFEF4444);
  static const _warning = Color(0xFFF59E0B);
  static const _success = Color(0xFF10B981);
  static const _accent = Color(0xFF3B82F6);

  /// productId → quantity to return
  final Map<int, int> _returnQuantities = {};

  // Updated: Now using a String variable for the dropdown instead of a Controller
  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize quantities
    for (final item in widget.invoice.items) {
      _returnQuantities[item.productId] = 0;
    }
    // Set the first reason as default
    if (widget.reasons.isNotEmpty) {
      _selectedReason = widget.reasons.first;
    }
  }

  double get _totalRefund {
    double total = 0;
    for (final item in widget.invoice.items) {
      final qty = _returnQuantities[item.productId] ?? 0;
      total += qty * item.unitPrice;
    }
    return total;
  }

  int get _totalItemsSelected {
    return _returnQuantities.values.fold(0, (sum, q) => sum + q);
  }

  Future<void> _submit() async {
    if (_totalItemsSelected == 0) {
      _showSnack('Select at least one item to return.', _warning);
      return;
    }
    if (_selectedReason == null) {
      _showSnack('Please select a reason for the return.', _warning);
      return;
    }

    setState(() => _isSubmitting = true);

    final items = <Map<String, dynamic>>[];
    for (final item in widget.invoice.items) {
      final qty = _returnQuantities[item.productId] ?? 0;
      if (qty > 0) {
        items.add({
          'product_id': item.productId,
          'quantity': qty,
          'unit_price': item.unitPrice,
        });
      }
    }

    final result = await ReturnsFFI.instance.processReturn(
      invoiceId: widget.invoice.id,
      items: items,
      reason: _selectedReason!,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result == 0) {
      Navigator.of(context).pop(true);
    } else {
      _showSnack('Return failed (code $result). Please try again.', _danger);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(inv),
            const SizedBox(height: 20),
            _buildInvoiceSummary(inv),
            const SizedBox(height: 20),
            const Text(
              'Select items to return',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: _buildItemList(inv)),
            const SizedBox(height: 16),
            _buildReasonDropdown(), // Updated method name
            const SizedBox(height: 20),
            _buildFooter(inv),
          ],
        ),
      ),
    );
  }

  // ── UI sections ──────────────────────────────────────────────────────────

  Widget _buildHeader(ReturnableInvoice inv) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.assignment_return_outlined,
            color: _warning,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Process Return — Invoice #${inv.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Select items, set quantities, and select a reason',
                style: TextStyle(color: _textSub, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: _textSub),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummary(ReturnableInvoice inv) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _summaryCell('Client', inv.clientName ?? 'Walk-in'),
          _divider(),
          _summaryCell('Date', inv.createdAt.split(' ').first),
          _divider(),
          _summaryCell(
            'Payment',
            inv.isInstallment ? 'Installment' : 'Cash',
            valueColor: inv.isInstallment ? _warning : _success,
          ),
          _divider(),
          _summaryCell(
            'Total',
            '\$${inv.totalAmount.toStringAsFixed(2)}',
            valueColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textSub,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 32,
    color: _border,
    margin: const EdgeInsets.symmetric(horizontal: 16),
  );

  Widget _buildItemList(ReturnableInvoice inv) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: inv.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
        itemBuilder: (context, i) => _buildItemRow(inv.items[i]),
      ),
    );
  }

  Widget _buildItemRow(ReturnableItem item) {
    final currentQty = _returnQuantities[item.productId] ?? 0;
    final canReturn = item.quantityRemaining > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.barcode,
                  style: const TextStyle(
                    color: _textSub,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Sold: ${item.quantitySold}'
              '${item.quantityAlreadyReturned > 0 ? '\nReturned: ${item.quantityAlreadyReturned}' : ''}',
              style: const TextStyle(color: _textSub, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${item.unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: canReturn
                ? _buildQuantityStepper(item, currentQty)
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Fully returned',
                      style: TextStyle(color: _danger, fontSize: 11),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStepper(ReturnableItem item, int currentQty) {
    final max = item.quantityRemaining;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _stepperBtn(
          Icons.remove,
          currentQty > 0
              ? () => setState(
                  () => _returnQuantities[item.productId] = currentQty - 1,
                )
              : null,
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$currentQty',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _stepperBtn(
          Icons.add,
          currentQty < max
              ? () => setState(
                  () => _returnQuantities[item.productId] = currentQty + 1,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text('/ $max', style: const TextStyle(color: _textSub, fontSize: 11)),
      ],
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? _bg : _bg.withOpacity(0.5),
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: enabled ? Colors.white : _textSub, size: 16),
      ),
    );
  }

  // Updated Method: Dropdown instead of TextField
  Widget _buildReasonDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedReason,
      dropdownColor: _surface,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      iconEnabledColor: _accent,
      decoration: InputDecoration(
        labelText: 'Reason for return',
        labelStyle: const TextStyle(color: _textSub),
        filled: true,
        fillColor: _surface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
      items: widget.reasons.map((String reason) {
        return DropdownMenuItem<String>(value: reason, child: Text(reason));
      }).toList(),
      onChanged: _isSubmitting
          ? null
          : (String? newValue) {
              setState(() {
                _selectedReason = newValue;
              });
            },
    );
  }

  Widget _buildFooter(ReturnableInvoice inv) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Refund Total',
              style: TextStyle(color: _textSub, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '\$${_totalRefund.toStringAsFixed(2)}',
              style: const TextStyle(
                color: _success,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              inv.isInstallment
                  ? 'Will reduce client debt'
                  : 'Cash refund to customer',
              style: const TextStyle(color: _textSub, fontSize: 11),
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: _textSub,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_isSubmitting ? 'Processing...' : 'Confirm Return'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

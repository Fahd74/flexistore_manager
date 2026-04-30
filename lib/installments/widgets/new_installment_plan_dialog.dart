import 'package:flutter/material.dart';
import '../data/app_data_store.dart';
import '../../core/db_models.dart';

class NewInstallmentPlanDialog extends StatefulWidget {
  const NewInstallmentPlanDialog({Key? key}) : super(key: key);

  @override
  State<NewInstallmentPlanDialog> createState() =>
      _NewInstallmentPlanDialogState();
}

class _NewInstallmentPlanDialogState extends State<NewInstallmentPlanDialog> {
  DbClient? _selectedClient;
  int _selectedMonths = 12;
  final _itemCtrl     = TextEditingController();
  final _totalCtrl    = TextEditingController();
  final _downCtrl     = TextEditingController();
  final _interestCtrl = TextEditingController(text: '0');

  String? _error;

  static const _monthOptions = [3, 6, 9, 12, 18, 24, 36];

  @override
  void dispose() {
    _itemCtrl.dispose();
    _totalCtrl.dispose();
    _downCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final item     = _itemCtrl.text.trim();
    final total    = double.tryParse(_totalCtrl.text.trim());
    final down     = double.tryParse(_downCtrl.text.trim()) ?? 0;
    final interest = double.tryParse(_interestCtrl.text.trim()) ?? 0;

    if (_selectedClient == null) {
      setState(() => _error = 'Please select a client.');
      return;
    }
    if (item.isEmpty) {
      setState(() => _error = 'Please enter the item name.');
      return;
    }
    if (total == null || total <= 0) {
      setState(() => _error = 'Enter a valid total price.');
      return;
    }
    if (down < 0 || down >= total) {
      setState(() => _error = 'Down payment must be between 0 and total price.');
      return;
    }

    // Using invoiceId: 1 as placeholder for manual creation
    final success = await AppDataStore.instance.createInstallmentPlan(
      clientId: _selectedClient!.id,
      invoiceId: 1, 
      totalAmount: total,
      downPayment: down,
      months: _selectedMonths,
      interestRate: interest,
    );

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Text(
            'Plan created for ${_selectedClient!.name} — $item.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } else {
      setState(() => _error = 'Failed to create plan in database.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
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
                      child: const Icon(Icons.calendar_today,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'New Installment Plan',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Select Client ────────────────────────────────────────────
              _label('Select Client', required: true),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<DbClient>>(
                valueListenable: AppDataStore.instance.clientsNotifier,
                builder: (context, clients, _) {
                  return _dropdown<DbClient>(
                    hint: 'Choose a client',
                    value: _selectedClient,
                    items: clients
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.name}  ·  ${c.phone}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ))
                        .toList(),
                    onChanged: (c) => setState(() {
                      _selectedClient = c;
                      _error = null;
                    }),
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Item Name ────────────────────────────────────────────────
              _label('Item / Description', required: true),
              const SizedBox(height: 8),
              _textField(_itemCtrl, 'e.g. iPhone 14 Pro'),
              const SizedBox(height: 20),

              // ── Amounts ──────────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Total Price (\$)', required: true),
                      const SizedBox(height: 8),
                      _textField(_totalCtrl, '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Down Payment (\$)', required: false),
                      const SizedBox(height: 8),
                      _textField(_downCtrl, '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Terms ────────────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Number of Months', required: true),
                      const SizedBox(height: 8),
                      _dropdown<int>(
                        hint: 'Months',
                        value: _selectedMonths,
                        items: _monthOptions
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m Months',
                                      style: const TextStyle(
                                          color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedMonths = v ?? 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Interest Rate (%) — optional', required: false),
                      const SizedBox(height: 8),
                      _textField(_interestCtrl, '0',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true)),
                    ],
                  ),
                ),
              ]),

              // ── Error ────────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 16),
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
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 20),

              // ── Actions ──────────────────────────────────────────────────
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
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Create Installment Plan',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  Widget _label(String text, {required bool required}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        children: required
            ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
            : [],
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint,
      {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF475569)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
    );
  }

  Widget _dropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint,
              style: const TextStyle(color: Color(0xFF475569), fontSize: 14)),
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF475569)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

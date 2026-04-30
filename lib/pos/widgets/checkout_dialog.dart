import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../data/cart_state.dart';
import '../../installments/data/app_data_store.dart';
import '../../core/db_models.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const CheckoutDialog(),
    );
  }

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  DbClient? _selectedClient;
  late bool _isCash;
  
  @override
  void initState() {
    super.initState();
    _isCash = CartState.instance.paymentMethod == 'cash';
  }
  final _monthsCtrl = TextEditingController(text: '12');
  final _downCtrl   = TextEditingController(text: '0');
  final _interestCtrl = TextEditingController(text: '0');
  String? _error;

  double get _subtotal => CartState.instance.cartTotal;
  double get _total    => _subtotal * 1.10;
  int    get _months   => int.tryParse(_monthsCtrl.text.trim()) ?? 1;
  double get _down     => double.tryParse(_downCtrl.text.trim()) ?? 0;
  double get _rate     => double.tryParse(_interestCtrl.text.trim()) ?? 0;
  double get _monthly  {
    if (_months <= 0) return _total - _down;
    final principal = _total - _down;
    final interest = principal * (_rate / 100);
    return (principal + interest) / _months;
  }

  static const _monthOptions = [3, 6, 9, 12, 18, 24, 36];

  @override
  void dispose() {
    _monthsCtrl.dispose();
    _downCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 650),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildClientSelector(),
                    const SizedBox(height: 20),
                    _buildPaymentToggle(),
                    if (!_isCash) ...[
                      const SizedBox(height: 20),
                      _buildInstallmentInputs(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                      ]),
                    ],
                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildSummary(),
                    const SizedBox(height: 28),
                    _buildActions(),
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
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF4ADE80), size: 24),
      ),
      const SizedBox(width: 14),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Checkout', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        SizedBox(height: 2),
        Text('Finalize the current sale', style: TextStyle(color: Colors.white38, fontSize: 13)),
      ]),
      const Spacer(),
      InkWell(
        onTap: () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close, color: Colors.white38, size: 20),
        ),
      ),
    ]);
  }

  Widget _buildClientSelector() {
    return ValueListenableBuilder<List<DbClient>>(
      valueListenable: AppDataStore.instance.clientsNotifier,
      builder: (context, clients, _) {
        final items = <DropdownMenuItem<DbClient?>>[
          const DropdownMenuItem<DbClient?>(
            value: null,
            child: Row(children: [
              Icon(Icons.person_outline, color: Colors.white38, size: 18),
              const SizedBox(width: 10),
              Text('Walking Customer', style: TextStyle(color: Colors.white, fontSize: 14)),
            ]),
          ),
          ...clients.map((c) => DropdownMenuItem<DbClient?>(
                value: c,
                child: Row(children: [
                  const Icon(Icons.person, color: Color(0xFF60A5FA), size: 18),
                  const SizedBox(width: 10),
                  Text('${c.name}  ·  ${c.phone}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              )),
        ];

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Client', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DbClient?>(
                value: _selectedClient,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
                items: items,
                onChanged: (v) => setState(() {
                  _selectedClient = v;
                  _error = null;
                  if (v == null) _isCash = true;
                }),
              ),
            ),
          ),
          if (_selectedClient == null && !_isCash)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Select a client to use installments.',
                  style: TextStyle(color: Colors.amber.shade300, fontSize: 11)),
            ),
        ]);
      },
    );
  }

  Widget _buildPaymentToggle() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Payment Method', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _paymentOption(
          label: 'Cash', icon: Icons.attach_money_rounded,
          selected: _isCash, selectedColor: const Color(0xFF22C55E),
          onTap: () => setState(() => _isCash = true),
        )),
        const SizedBox(width: 12),
        Expanded(child: _paymentOption(
          label: 'Installments', icon: Icons.calendar_month_rounded,
          selected: !_isCash, selectedColor: const Color(0xFF3B82F6),
          onTap: _selectedClient == null ? null : () => setState(() => _isCash = false),
        )),
      ]),
    ]);
  }

  Widget _paymentOption({
    required String label, required IconData icon,
    required bool selected, required Color selectedColor, VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFF0F172A) : selected ? selectedColor.withOpacity(0.12) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled ? const Color(0xFF1E293B) : selected ? selectedColor.withOpacity(0.5) : const Color(0xFF334155),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: disabled ? Colors.white12 : selected ? selectedColor : Colors.white38, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: disabled ? Colors.white12 : selected ? selectedColor : Colors.white54,
            fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildInstallmentInputs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.15)),
      ),
      child: Column(children: [
        Row(children: [
          const Expanded(child: Text('Number of Months', style: TextStyle(color: Colors.white70, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _months,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 18),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                items: _monthOptions.map((m) => DropdownMenuItem(value: m, child: Text('$m mo'))).toList(),
                onChanged: (v) => setState(() => _monthsCtrl.text = '${v ?? 12}'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Down Payment (\$)', style: TextStyle(color: Colors.white70, fontSize: 13))),
          SizedBox(
            width: 110, height: 40,
            child: TextField(
              controller: _downCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                filled: true, fillColor: const Color(0xFF1E293B),
                prefixText: '\$ ', prefixStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Interest Rate (%)', style: TextStyle(color: Colors.white70, fontSize: 13))),
          SizedBox(
            width: 110, height: 40,
            child: TextField(
              controller: _interestCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                filled: true, fillColor: const Color(0xFF1E293B),
                suffixText: '% ', suffixStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Monthly Payment', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('\$${_monthly.toStringAsFixed(2)} / mo',
                style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDivider() => Container(
    height: 1,
    decoration: BoxDecoration(gradient: LinearGradient(colors: [
      Colors.transparent, Colors.white.withOpacity(0.08), Colors.transparent,
    ])),
  );

  Widget _buildSummary() {
    final tax = _subtotal * 0.10;
    return Column(children: [
      _row('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
      const SizedBox(height: 6),
      _row('Tax (10%)', '\$${tax.toStringAsFixed(2)}'),
      if (!_isCash && _down > 0) ...[
        const SizedBox(height: 6),
        _row('Down Payment', '-\$${_down.toStringAsFixed(2)}'),
      ],
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      ]),
      if (!_isCash) ...[
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$_months × monthly', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text('\$${_monthly.toStringAsFixed(2)} / mo',
              style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ],
    ]);
  }

  Widget _row(String label, String value) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    Text(value, style: const TextStyle(color: Colors.white54, fontSize: 13)),
  ]);

  Widget _buildActions() => Row(children: [
    Expanded(child: SizedBox(height: 48, child: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white54,
        side: const BorderSide(color: Color(0xFF334155)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ))),
    const SizedBox(width: 14),
    Expanded(flex: 2, child: SizedBox(height: 48, child: ElevatedButton.icon(
      onPressed: _confirm,
      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
      label: const Text('Confirm Sale', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white,
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ))),
  ]);

  Future<void> _confirm() async {
    if (!_isCash) {
      if (_selectedClient == null) { setState(() => _error = 'Select a client to create an installment plan.'); return; }
      if (_down < 0 || _down >= _total) { setState(() => _error = 'Down payment must be between \$0 and \$${_total.toStringAsFixed(2)}.'); return; }
      if (_months <= 0) { setState(() => _error = 'Months must be greater than 0.'); return; }
    }

    final cartItems = CartState.instance.itemsNotifier.value;
    if (cartItems.isEmpty) { setState(() => _error = 'Cart is empty.'); return; }

    final itemsJson = jsonEncode(cartItems.map((i) => {
      'product_id': i.productId,
      'quantity': i.quantity,
      'unit_price': i.price,
    }).toList());

    try {
      // Create Sale (Invoice)
      // Using userId: 1 for now
      final invoiceId = await AppDataStore.instance.createSale(
        clientId: _selectedClient?.id,
        userId: 1,
        totalAmount: _total,
        paymentMethod: _isCash ? 'cash' : 'installments',
        itemsJson: itemsJson,
      );

      if (invoiceId <= 0) {
        setState(() => _error = 'Failed to create sale in database.');
        return;
      }

      if (!_isCash && _selectedClient != null) {
        final success = await AppDataStore.instance.createInstallmentPlan(
          clientId: _selectedClient!.id,
          invoiceId: invoiceId,
          totalAmount: _total,
          downPayment: _down,
          months: _months,
          interestRate: _rate,
        );
        if (!success) {
           setState(() => _error = 'Sale created (ID: $invoiceId), but failed to create installment plan.');
           return;
        }
      }

      Navigator.of(context).pop();
      CartState.instance.clearCart();

      final msg = _isCash
          ? 'Sale confirmed — Cash ✓'
          : 'Installment plan created for ${_selectedClient!.name} ✓';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    } catch (e) {
      setState(() => _error = 'Error during checkout: $e');
    }
  }
}

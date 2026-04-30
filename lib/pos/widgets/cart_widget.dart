import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/cart_state.dart';
import 'checkout_dialog.dart';

class CartWidget extends StatelessWidget {
  const CartWidget({super.key});

  CartState get _cart => CartState.instance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      child: ValueListenableBuilder<List<CartItem>>(
        valueListenable: _cart.itemsNotifier,
        builder: (context, items, _) {
          final subtotal = _cart.cartTotal;
          final tax   = subtotal * 0.10;
          final total = subtotal + tax;
          final count = _cart.itemCount;

          return LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              return Column(
                children: [
                  _buildHeader(count),
                  const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),
                  _buildPaymentToggle(h),
                  const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),
                  Expanded(child: items.isEmpty ? _buildEmptyState() : _buildCartList(items)),
                  const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),
                  _buildFooter(context, subtotal, tax, total, items, h),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF3B82F6), size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Current Sale',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 1),
          Text('$count item${count == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      ]),
    );
  }

  // ── Payment toggle ───────────────────────────────────────────────────────────
  Widget _buildPaymentToggle(double h) {
    return ValueListenableBuilder<String>(
      valueListenable: _cart.paymentMethodNotifier,
      builder: (context, method, _) {
        final isCash = method == 'cash';
        final btnH = 56.0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(child: InkWell(
              onTap: () => _cart.paymentMethodNotifier.value = 'cash',
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isCash ? const Color(0xFF22C55E).withOpacity(0.05) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCash ? const Color(0xFF22C55E).withOpacity(0.5) : const Color(0xFF334155),
                    width: isCash ? 1.5 : 1,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.attach_money, color: isCash ? const Color(0xFF22C55E) : Colors.white38, size: 20),
                  Text('Cash', style: TextStyle(
                    color: isCash ? const Color(0xFF22C55E) : Colors.white38, 
                    fontSize: 12, 
                    fontWeight: isCash ? FontWeight.w600 : FontWeight.w500
                  )),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: InkWell(
              onTap: () => _cart.paymentMethodNotifier.value = 'installment',
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: btnH,
                decoration: BoxDecoration(
                  color: !isCash ? const Color(0xFF3B82F6).withOpacity(0.05) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !isCash ? const Color(0xFF3B82F6).withOpacity(0.5) : const Color(0xFF334155),
                    width: !isCash ? 1.5 : 1,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.credit_card, color: !isCash ? const Color(0xFF3B82F6) : Colors.white38, size: 20),
                  Text('Installment', style: TextStyle(
                    color: !isCash ? const Color(0xFF3B82F6) : Colors.white38, 
                    fontSize: 12, 
                    fontWeight: !isCash ? FontWeight.w600 : FontWeight.w500
                  )),
                ]),
              ),
            )),
          ]),
        );
      },
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.shopping_cart_outlined, color: Colors.white.withOpacity(0.05), size: 60),
      const SizedBox(height: 16),
      const Text('Cart is empty', style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Add items to start', style: TextStyle(color: Colors.white24, fontSize: 13)),
    ]));
  }

  // ── Cart list ────────────────────────────────────────────────────────────────
  Widget _buildCartList(List<CartItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          dense: true,
          title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('\$${item.price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white38, size: 18), onPressed: () => _cart.updateQuantity(item.productId, -1)),
            Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white38, size: 18), onPressed: () => _cart.updateQuantity(item.productId, 1)),
          ]),
        );
      },
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context, double subtotal, double tax, double total, List<CartItem> items, double h) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Align(alignment: Alignment.centerLeft, child: Text('Discount %', style: TextStyle(color: Colors.white24, fontSize: 11))),
          )),
          const SizedBox(width: 8),
          TextButton(onPressed: () => _cart.clearCart(), child: const Text('Clear', style: TextStyle(color: Colors.white54, fontSize: 11))),
        ]),
        const SizedBox(height: 8),
        _summaryRow('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
        const SizedBox(height: 2),
        _summaryRow('Tax (10%)', '\$${tax.toStringAsFixed(2)}'),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: SizedBox(height: 38, child: OutlinedButton(
            onPressed: () => _cart.clearCart(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Color(0xFF334155)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: SizedBox(height: 38, child: ElevatedButton(
            onPressed: items.isEmpty ? null : () => CheckoutDialog.show(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Complete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ))),
        ]),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    Text(value, style: const TextStyle(color: Colors.white54, fontSize: 13)),
  ]);
}

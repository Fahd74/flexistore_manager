import 'package:flutter/material.dart';

import '../widgets/product_search_widget.dart';
import '../widgets/cart_widget.dart';

// ── Returns module integration ──
import '../../returns/data/returns_ffi.dart';
import '../../returns/widgets/process_return_dialog.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────
const _kSurface = Color(0xFF0F172A);
const _kCard = Color(0xFF1E293B);
const _kBorder = Color(0xFF334155);
const _kAccent = Color(0xFF3B82F6);
const _kOrange = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kGreen = Color(0xFF22C55E);
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFF94A3B8);

/// Default list of return reasons shown in the ProcessReturnDialog dropdown.
/// Edit this list to customize the available reasons across both POS + Returns page.
const List<String> _kReturnReasons = [
  'Defective product',
  'Customer changed mind',
  'Wrong item',
  'Damaged in transit',
  'Other',
];

/// Main POS screen — desktop split layout with Return functionality.
///
/// ┌────────────────────────┬──────────────┐
/// │  Product Search (65%)  │  Cart (35%)  │
/// └────────────────────────┴──────────────┘
///
/// The "Return" button in the top-right opens the same full-featured
/// ProcessReturnDialog used by the Returns page, ensuring a consistent UX.
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left: Products + Return Button ────────────────────────────────
        Expanded(
          flex: 65,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildActionBar(context),
                const SizedBox(height: 12),
                const Expanded(child: ProductSearchWidget()),
              ],
            ),
          ),
        ),

        // ── Right: Cart ───────────────────────────────────────────────────
        const Expanded(
          flex: 35,
          child: CartWidget(),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Row(
      children: [
        const Row(
          children: [
            Icon(Icons.storefront_rounded, color: _kAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Point of Sale',
              style: TextStyle(
                color: _kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Spacer(),

        // Return button — opens invoice-ID prompt, then ProcessReturnDialog
        OutlinedButton.icon(
          onPressed: () => _startReturnFlow(context),
          icon: const Icon(Icons.assignment_return_rounded, size: 18),
          label: const Text('Return',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kOrange,
            side: const BorderSide(color: _kOrange),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }

  /// Two-step return flow:
  ///   1. Ask for invoice ID
  ///   2. Look it up via ReturnsFFI
  ///   3. Open the full ProcessReturnDialog (same widget the Returns page uses)
  Future<void> _startReturnFlow(BuildContext context) async {
    // Step 1: ask for the invoice ID
    final invoiceIdStr = await _askForInvoiceId(context);
    if (invoiceIdStr == null) return; // user cancelled

    final trimmed = invoiceIdStr.trim();
    if (trimmed.isEmpty) return;

    final invoiceId = int.tryParse(trimmed);
    if (invoiceId == null || invoiceId <= 0) {
      if (!context.mounted) return;
      _showSnack(context, 'Invoice ID must be a valid number', _kRed);
      return;
    }

    // Step 2: fetch the invoice
    final invoice = await ReturnsFFI.instance.getInvoiceForReturn(invoiceId);
    if (!context.mounted) return;

    if (invoice == null) {
      _showSnack(
        context,
        'Invoice #$invoiceId not found or already fully returned',
        _kRed,
      );
      return;
    }

    // Step 3: open the same dialog used on the Returns page
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProcessReturnDialog(
        invoice: invoice,
        reasons: _kReturnReasons,
      ),
    );

    if (!context.mounted) return;
    if (success == true) {
      _showSnack(context, 'Return processed successfully', _kGreen);
    }
  }

  /// Small prompt dialog asking the user for an invoice ID.
  Future<String?> _askForInvoiceId(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: _kOrange, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Start a Return',
                      style: TextStyle(
                        color: _kTextPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _kTextSecondary, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter the original invoice ID to load its items',
                  style: TextStyle(color: _kTextSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.tag_rounded,
                          color: _kTextSecondary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              color: _kTextPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Invoice ID (e.g. 42)',
                            hintStyle:
                                TextStyle(color: _kTextSecondary, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: (v) => Navigator.of(ctx).pop(v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: _kTextSecondary,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.of(ctx).pop(controller.text),
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Lookup',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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

  void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
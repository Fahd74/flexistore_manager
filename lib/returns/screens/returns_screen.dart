import 'package:flutter/material.dart';
import '../data/returns_ffi.dart';
import '../widgets/process_return_dialog.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  // ── Theme Colors ──
  static const _bg = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _border = Color(0xFF334155);
  static const _textSub = Color(0xFF94A3B8);
  static const _accent = Color(0xFF3B82F6);
  static const _danger = Color(0xFFEF4444);
  static const _warning = Color(0xFFF59E0B);
  static const _success = Color(0xFF10B981);

  // ── Dropdown Reasons ──
  final List<String> _returnReasons = [
    'Defective Product',
    'Wrong Item Delivered',
    'Customer Changed Mind',
    'Expired Goods',
    'Damaged in Shipping',
    'Other',
  ];

  final TextEditingController _invoiceIdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  ReturnsStats _stats = ReturnsStats(totalReturns: 0, totalRefunded: 0, returnsToday: 0);
  List<ReturnRecord> _returns = [];
  bool _isLoading = true;
  bool _isLookingUpInvoice = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _invoiceIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    final stats = await ReturnsFFI.instance.getStats();
    final returns = await ReturnsFFI.instance.getAllReturns();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _returns = returns;
      _isLoading = false;
    });
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      _refreshAll();
      return;
    }
    setState(() => _isLoading = true);
    final results = await ReturnsFFI.instance.searchReturns(query.trim());
    if (!mounted) return;
    setState(() {
      _returns = results;
      _isLoading = false;
    });
  }

  Future<void> _lookupInvoice() async {
    final text = _invoiceIdController.text.trim();
    if (text.isEmpty) {
      _snack('Enter an invoice ID first.', _warning);
      return;
    }
    final invoiceId = int.tryParse(text);
    if (invoiceId == null) {
      _snack('Invoice ID must be a number.', _warning);
      return;
    }

    setState(() => _isLookingUpInvoice = true);
    final invoice = await ReturnsFFI.instance.getInvoiceForReturn(invoiceId);
    if (!mounted) return;
    setState(() => _isLookingUpInvoice = false);

    if (invoice == null) {
      _snack('Invoice #$invoiceId not found or already fully returned.', _danger);
      return;
    }

    // Opens Dialog with predefined reasons
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProcessReturnDialog(
        invoice: invoice,
        reasons: _returnReasons,
      ),
    );

    if (success == true) {
      _invoiceIdController.clear();
      _snack('Return processed successfully.', _success);
      _refreshAll();
    }
  }

  void _snack(String msg, Color color) {
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
    return Container(
      color: _bg,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildInvoiceLookupCard(),
            const SizedBox(height: 24),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.keyboard_return_outlined, color: _warning, size: 28),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Returns Management',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Process returns and manage inventory restock',
                style: TextStyle(color: _textSub, fontSize: 14)),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _refreshAll,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'Total Returns', value: '${_stats.totalReturns}', icon: Icons.assignment_return_outlined, color: _accent)),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(title: 'Total Refunded', value: '\$${_stats.totalRefunded.toStringAsFixed(2)}', icon: Icons.payments_outlined, color: _success)),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(title: 'Returns Today', value: '${_stats.returnsToday}', icon: Icons.today_outlined, color: _warning)),
      ],
    );
  }

  Widget _buildInvoiceLookupCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _surface, border: Border.all(color: _border), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start a Return', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Enter an invoice ID to begin', style: TextStyle(color: _textSub, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _invoiceIdController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Invoice ID...',
                hintStyle: const TextStyle(color: _textSub),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLookingUpInvoice ? null : _lookupInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent, 
              foregroundColor: Colors.white, // This makes the text white
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Matches your theme
            ),
            child: Text(_isLookingUpInvoice ? '...' : 'Lookup Invoice'),
          ), ]
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Return History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1, color: _border),
          _buildHistoryTable(),
        ],
      ),
    );
  }

  Widget _buildHistoryTable() {
    if (_isLoading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_bg),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Original Inv')),
                DataColumn(label: Text('Client')),
                DataColumn(label: Text('Refund')),
                DataColumn(label: Text('Reason')),
                DataColumn(label: Text('Date')),
              ],
              rows: _returns.map((r) => DataRow(cells: [
                DataCell(Text('#${r.id}')),
                DataCell(Text('#${r.invoiceId}', style: const TextStyle(color: _accent))),
                DataCell(Text(r.clientName ?? 'Walk-in')),
                DataCell(Text('\$${r.refundAmount.toStringAsFixed(2)}', style: const TextStyle(color: _success))),
                DataCell(Text(r.reason)),
                DataCell(Text(r.createdAt)),
              ])).toList(),
            ),
          ),
        );
      }
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
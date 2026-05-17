import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/audit_ffi.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InventoryHistoryScreen extends StatefulWidget {
  const InventoryHistoryScreen({super.key});

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  List<dynamic> _allLogs = [];
  List<dynamic> _filteredLogs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedType = 'All Types';

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final jsonString = AuditNativeAPI.instance.getInventoryLogs();
    try {
      final data = jsonDecode(jsonString) as List<dynamic>;
      if (mounted) {
        setState(() {
          _allLogs = data;
          _isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      print('Error parsing JSON: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        final id = log['id']?.toString() ?? '';
        final productId = log['product_id']?.toString() ?? '';
        final actionType = log['action_type']?.toString().toUpperCase() ?? '';
        
        bool matchesSearch = id.contains(_searchQuery) || productId.contains(_searchQuery) || actionType.contains(_searchQuery.toUpperCase());
        
        bool matchesType = true;
        if (_selectedType != 'All Types') {
          if (_selectedType == 'Restock' && actionType != 'RESTOCK') matchesType = false;
          if (_selectedType == 'Sale' && actionType != 'SALE') matchesType = false;
          if (_selectedType == 'Return' && actionType != 'RETURN') matchesType = false;
          if (_selectedType == 'Delete' && actionType != 'DELETE') matchesType = false;
          if (_selectedType == 'Add New Product' && actionType != 'ADD_PRODUCT') matchesType = false;
        }

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Inventory History Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['ID', 'Date', 'Product ID', 'Action', 'Quantity', 'User ID'],
                  ..._filteredLogs.map((log) {
                    final rawAction = log['action_type']?.toString().toUpperCase() ?? '';
                    String actionType = rawAction;
                    if (rawAction == 'RESTOCK') actionType = 'restoke';
                    else if (rawAction == 'SALE') actionType = 'sale';
                    else if (rawAction == 'RETURN') actionType = 'return';
                    else if (rawAction == 'DELETE') actionType = 'delete';
                    else if (rawAction == 'ADD_PRODUCT') actionType = 'add new product';

                    return [
                      log['id']?.toString() ?? '',
                      log['created_at']?.toString() ?? '',
                      log['product_id']?.toString() ?? '',
                      actionType,
                      log['quantity_changed']?.toString() ?? '',
                      log['user_id']?.toString() ?? '',
                    ];
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
      );
    }

    int totalMovements = _filteredLogs.length;
    int stockIn = 0;
    int stockOut = 0;

    for (var log in _filteredLogs) {
      final int qty = (log['quantity_changed'] is num) ? (log['quantity_changed'] as num).toInt() : 0;
      if (qty > 0) {
        stockIn += qty;
      } else if (qty < 0) {
        stockOut += qty;
      }
    }
    
    int netChange = stockIn + stockOut;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Page Header
          _buildHeader(),
          const SizedBox(height: 24),

          // KPI Cards Row
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  icon: Icons.history,
                  iconBgColor: const Color(0xFF1E3A8A),
                  iconColor: const Color(0xFF60A5FA),
                  title: 'Total Movements',
                  value: totalMovements.toString(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  icon: Icons.trending_up,
                  iconBgColor: const Color(0xFF064E3B),
                  iconColor: const Color(0xFF34D399),
                  title: 'Stock In',
                  value: '+$stockIn',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  icon: Icons.trending_down,
                  iconBgColor: const Color(0xFF7F1D1D),
                  iconColor: const Color(0xFFF87171),
                  title: 'Stock Out',
                  value: stockOut.toString(), // stockOut is already negative
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  icon: Icons.inventory_2_outlined,
                  iconBgColor: netChange >= 0 ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                  iconColor: netChange >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                  title: 'Net Change',
                  value: netChange >= 0 ? '+$netChange' : netChange.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search & Filter Bar
          _buildFilterBar(),
          const SizedBox(height: 24),

          // Data Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _filteredLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No inventory logs found.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : _buildDataTable(_filteredLogs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Inventory History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Track all inventory movements and stock changes',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _exportPdf,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Export Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          // Search Input
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by product ID or type...',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Dropdown 1
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E293B),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 20),
                  items: ['All Types', 'Restock', 'Sale', 'Return', 'Delete', 'Add New Product']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 14))))
                    .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _selectedType = val;
                      _applyFilters();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<dynamic> logs) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          color: const Color(0xFF0F172A),
          child: Row(
            children: const [
              Expanded(flex: 2, child: Text('Date & Time', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Product ID', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Action Type', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Quantity', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('User ID', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF334155)),
        // Rows
        Expanded(
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF334155)),
            itemBuilder: (context, index) {
              final log = logs[index];
              final productId = log['product_id']?.toString() ?? '0';
              final date = log['created_at']?.toString() ?? 'N/A';
              final actionTypeRaw = log['action_type']?.toString().toUpperCase() ?? '';
              final qty = (log['quantity_changed'] is num) ? (log['quantity_changed'] as num).toInt() : 0;
              final userId = log['user_id']?.toString() ?? 'N/A';

              String typeText = actionTypeRaw;
              Color typeColor = const Color(0xFF10B981);
              IconData typeIcon = Icons.arrow_upward;

              if (actionTypeRaw == 'RESTOCK') { typeText = 'restoke'; typeColor = const Color(0xFF10B981); typeIcon = Icons.arrow_upward; }
              else if (actionTypeRaw == 'SALE') { typeText = 'sale'; typeColor = const Color(0xFFEF4444); typeIcon = Icons.arrow_downward; }
              else if (actionTypeRaw == 'RETURN') { typeText = 'return'; typeColor = const Color(0xFF3B82F6); typeIcon = Icons.loop; }
              else if (actionTypeRaw == 'DELETE') { typeText = 'delete'; typeColor = const Color(0xFFF59E0B); typeIcon = Icons.delete; }
              else if (actionTypeRaw == 'ADD_PRODUCT') { typeText = 'add new product'; typeColor = const Color(0xFF8B5CF6); typeIcon = Icons.add; }

              final qtyStr = qty > 0 ? '+$qty' : qty.toString();
              final qtyColor = qty > 0 ? const Color(0xFF34D399) : const Color(0xFFF87171);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2, 
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: Colors.white54, size: 14),
                          const SizedBox(width: 8),
                          Text(date, style: const TextStyle(color: Colors.white70)),
                        ]
                      )
                    ),
                    Expanded(
                      flex: 2, 
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Color(0xFFD946EF), size: 16),
                          const SizedBox(width: 8),
                          Text('Product $productId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        ]
                      )
                    ),
                    Expanded(
                      flex: 2, 
                      child: UnconstrainedBox(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: typeColor.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(typeIcon, color: typeColor, size: 12),
                              const SizedBox(width: 4),
                              Text(typeText, style: TextStyle(color: typeColor, fontSize: 12)),
                            ],
                          )
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2, 
                      child: Text(qtyStr, style: TextStyle(color: qtyColor, fontWeight: FontWeight.bold, fontSize: 15))
                    ),
                    Expanded(
                      flex: 2, 
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Text('User $userId', style: const TextStyle(color: Colors.white70)),
                        ]
                      )
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

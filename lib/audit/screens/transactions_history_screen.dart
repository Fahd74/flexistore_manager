import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/audit_ffi.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  State<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen> {
  List<dynamic> _allTransactions = [];
  List<dynamic> _filteredTransactions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All Status';
  String _selectedPayment = 'All Payment';

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final jsonString = AuditNativeAPI.instance.getTransactionLogs();
    try {
      final data = jsonDecode(jsonString) as List<dynamic>;
      if (mounted) {
        setState(() {
          _allTransactions = data;
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
      _filteredTransactions = _allTransactions.where((txn) {
        final id = txn['id']?.toString() ?? '';
        final actionType = txn['action_type']?.toString().toUpperCase() ?? '';
        final amountStr = txn['amount']?.toString() ?? '';
        
        // Search
        bool matchesSearch = id.contains(_searchQuery) || actionType.contains(_searchQuery.toUpperCase()) || amountStr.contains(_searchQuery);
        
        // Status filter (simplified since real data doesn't have pending)
        bool matchesStatus = true;
        if (_selectedStatus != 'All Status') {
          if (_selectedStatus == 'Completed' && actionType.contains('CANCEL')) matchesStatus = false;
          if (_selectedStatus == 'Pending' && !actionType.contains('PENDING')) matchesStatus = false;
        }

        // Payment filter
        bool matchesPayment = true;
        if (_selectedPayment != 'All Payment') {
          if (_selectedPayment == 'Cash' && !(actionType.contains('CASH_SALE') || actionType == 'SALE')) matchesPayment = false;
          if (_selectedPayment == 'Installment' && !(actionType.contains('INSTALLMENT') || actionType == 'INSTALLMENT')) matchesPayment = false;
        }

        return matchesSearch && matchesStatus && matchesPayment;
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
              pw.Text('Transactions History Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['ID', 'Date', 'Action Type', 'Amount', 'User ID'],
                  ..._filteredTransactions.map((txn) {
                    final rawAction = txn['action_type']?.toString().toUpperCase() ?? '';
                    String actionType = rawAction;
                    if (rawAction.contains('CASH_SALE') || rawAction.contains('SALE')) actionType = 'Cash';
                    else if (rawAction.contains('INSTALLMENT') || rawAction.contains('INSTALLMENT')) actionType = 'Installment';
                    else if (rawAction.contains('RETURN') || rawAction.contains('RETURN')) actionType = 'Return';
                    else if (rawAction == 'ADD_CLIENT') actionType = 'Add New Client';
                    else if (rawAction == 'EDIT_CLIENT') actionType = 'Edit Client';

                    return [
                      txn['id']?.toString() ?? '',
                      txn['created_at']?.toString() ?? '',
                      actionType,
                      (txn['amount'] ?? 0).toString(),
                      txn['user_id']?.toString() ?? '',
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

    int totalTransactions = _filteredTransactions.length;
    double totalAmount = 0;
    int completedCount = 0;
    int pendingCount = 0;

    for (var txn in _filteredTransactions) {
      final double amount = (txn['amount'] is num) ? (txn['amount'] as num).toDouble() : 0.0;
      totalAmount += amount;
      completedCount++; // Assuming all fetched are completed for now
    }

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
                  title: 'Total Transactions',
                  value: totalTransactions.toString(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  icon: Icons.attach_money,
                  iconBgColor: const Color(0xFF064E3B),
                  iconColor: const Color(0xFF34D399),
                  title: 'Total Amount',
                  value: '\$${totalAmount.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  icon: Icons.check_circle_outline,
                  iconBgColor: const Color(0xFF064E3B),
                  iconColor: const Color(0xFF34D399),
                  title: 'Completed',
                  value: completedCount.toString(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  icon: Icons.access_time,
                  iconBgColor: const Color(0xFF78350F),
                  iconColor: const Color(0xFFFBBF24),
                  title: 'Pending',
                  value: pendingCount.toString(),
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
                child: _filteredTransactions.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions found.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : _buildDataTable(_filteredTransactions),
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
              'Transaction History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Complete logs of all sales and transactions',
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
                hintText: 'Search by transaction ID or action...',
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
            child: _buildDropdown(
              ['All Status', 'Completed', 'Pending'],
              _selectedStatus,
              (val) {
                if (val != null) {
                  _selectedStatus = val;
                  _applyFilters();
                }
              }
            ),
          ),
          const SizedBox(width: 16),
          
          // Dropdown 2
          Expanded(
            flex: 1,
            child: _buildDropdown(
              ['All Payment', 'Cash', 'Installment'],
              _selectedPayment,
              (val) {
                if (val != null) {
                  _selectedPayment = val;
                  _applyFilters();
                }
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String currentValue, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 20),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDataTable(List<dynamic> transactions) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          color: const Color(0xFF0F172A),
          child: Row(
            children: const [
              Expanded(flex: 2, child: Text('Transaction ID', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Date & Time', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Action Type', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Amount', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('User ID', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF334155)),
        // Rows
        Expanded(
          child: ListView.separated(
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF334155)),
            itemBuilder: (context, index) {
              final txn = transactions[index];
              final id = txn['id']?.toString() ?? '0';
              final formattedId = 'TXN-2026-${id.padLeft(5, '0')}';
              final date = txn['created_at']?.toString() ?? 'N/A';
              final amount = (txn['amount'] is num) ? (txn['amount'] as num).toDouble() : 0.0;
              final actionTypeRaw = txn['action_type']?.toString() ?? '';
              final userId = txn['user_id']?.toString() ?? 'N/A';
              
              // Map action types
              String actionType = actionTypeRaw;
              Color actionColor = const Color(0xFF60A5FA);
              
              if (actionTypeRaw.contains('CASH_SALE') || actionTypeRaw == 'SALE') { actionType = 'Cash'; actionColor = const Color(0xFF34D399); }
              else if (actionTypeRaw.contains('INSTALLMENT') || actionTypeRaw == 'INSTALLMENT') { actionType = 'Installment'; actionColor = const Color(0xFF8B5CF6); }
              else if (actionTypeRaw.contains('RETURN') || actionTypeRaw == 'RETURN') { actionType = 'Return'; actionColor = const Color(0xFFF59E0B); }
              else if (actionTypeRaw == 'ADD_CLIENT') { actionType = 'Add New Client'; actionColor = const Color(0xFF60A5FA); }
              else if (actionTypeRaw == 'EDIT_CLIENT') { actionType = 'Edit Client'; actionColor = const Color(0xFF60A5FA); }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2, 
                      child: Row(
                        children: [
                          const Icon(Icons.history, color: Color(0xFF60A5FA), size: 16),
                          const SizedBox(width: 8),
                          Text(formattedId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ]
                      )
                    ),
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
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: actionColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: actionColor.withOpacity(0.5)),
                          ),
                          child: Text(actionType, style: TextStyle(color: actionColor, fontSize: 12)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2, 
                      child: Text(
                        '\$${amount.toStringAsFixed(2)}', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      )
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

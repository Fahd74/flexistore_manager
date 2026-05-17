import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/dashboard_ffi.dart';
import '../widgets/stat_card_widget.dart';
import '../../auth/data/session_ffi.dart';
import '../../inventory/data/inventory_ffi.dart';
import '../../audit/data/audit_ffi.dart';
import '../../clients/data/clients_ffi.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardFFI _ffi = DashboardFFI();
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<Map<String, dynamic>> _loadData() async {
    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final stats = await _ffi.getStats(userId);
    
    // Inventory Low Stock
    final products = await InventoryFFI.instance.getProducts();
    final lowStockProducts = products.where((p) => p.stockQuantity <= 5 && p.status == 'active').toList();
    lowStockProducts.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

    // Recent Transactions
    final txLogsStr = AuditNativeAPI.instance.getTransactionLogs();
    List<dynamic> txLogs = [];
    try {
      txLogs = jsonDecode(txLogsStr);
    } catch (_) {}

    // Calculate Today's Sales and Returns
    double todaysSales = 0.0;
    double todaysReturns = 0.0;
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Calculate 7-day revenue chart
    Map<String, double> last7DaysSales = {};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      last7DaysSales[dateStr] = 0.0;
    }

    for (var tx in txLogs) {
      final action = tx['action_type']?.toString().toUpperCase() ?? '';
      final amount = (tx['amount'] is num) ? (tx['amount'] as num).toDouble() : 0.0;
      final createdAt = tx['created_at']?.toString() ?? '';
      
      if (createdAt.startsWith(todayStr)) {
        if (action.contains('SALE')) todaysSales += amount;
        if (action.contains('RETURN')) todaysReturns += amount;
      }

      // 7-days chart aggregation
      if (action.contains('SALE')) {
        final txDate = createdAt.split(' ').first;
        if (last7DaysSales.containsKey(txDate)) {
          last7DaysSales[txDate] = last7DaysSales[txDate]! + amount;
        }
      }
    }

    // Clients Stats
    final clientsStr = ClientsFFI.instance.getAllClients(userId);
    List<dynamic> clients = [];
    try {
      clients = jsonDecode(clientsStr);
    } catch (_) {}

    int activeClients = 0;
    int debtClients = 0;
    for (var c in clients) {
      final status = c['status']?.toString() ?? 'Active';
      final debt = (c['total_debt'] is num) ? (c['total_debt'] as num).toDouble() : 0.0;
      if (status == 'Active' && debt <= 0) {
        activeClients++;
      }
      if (debt > 0 || status == 'Has Debt' || status == 'Overdue') {
        debtClients++;
      }
    }

    return {
      'stats': stats,
      'lowStockProducts': lowStockProducts.take(4).toList(),
      'transactions': txLogs.take(5).toList(),
      'todaysSales': todaysSales,
      'todaysReturns': todaysReturns,
      'activeClients': activeClients,
      'debtClients': debtClients,
      'last7DaysSales': last7DaysSales,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep dark background
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load dashboard data:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refreshStats,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                    ),
                  )
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final stats = data['stats'] as DashboardData;
          final lowStockProducts = data['lowStockProducts'] as List<Product>;
          final transactions = data['transactions'] as List<dynamic>;

          final todaysSales = data['todaysSales'] as double;
          final todaysReturns = data['todaysReturns'] as double;
          final activeClients = data['activeClients'] as int;
          final debtClients = data['debtClients'] as int;
          final last7DaysSales = data['last7DaysSales'] as Map<String, dynamic>;

          if (stats.error != null) {
            return Center(
              child: Text(
                'Database Error: ${stats.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 18),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatCards(todaysSales, todaysReturns, activeClients, debtClients),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildRevenueChart(last7DaysSales),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 1,
                        child: _buildRecentTransactions(transactions),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildLowStockAlerts(stats.lowStock, lowStockProducts),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Welcome back! Here's what's happening today.",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 16,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildActionButton(
              icon: Icons.point_of_sale,
              label: 'New Sale',
              bgColor: const Color(0xFF1E293B),
              textColor: Colors.white,
              onTap: () => context.go('/pos'),
            ),
            const SizedBox(width: 16),
            _buildActionButton(
              icon: Icons.inventory_2_outlined,
              label: 'Add Product',
              bgColor: const Color(0xFF334155),
              textColor: const Color(0xFFCBD5E1),
              onTap: () => context.go('/inventory'),
            ),
            const SizedBox(width: 16),
            _buildActionButton(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Add Client',
              bgColor: const Color(0xFF334155),
              textColor: const Color(0xFFCBD5E1),
              onTap: () => context.go('/clients'),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(double todaysSales, double todaysReturns, int activeClients, int debtClients) {
    return Row(
      children: [
        Expanded(
          child: StatCardWidget(
            title: "Today's Sales",
            value: "\$${todaysSales.toStringAsFixed(0)}",
            changeText: "Today's transactions",
            isUp: true,
            icon: Icons.attach_money,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: StatCardWidget(
            title: "Today's Returns",
            value: "\$${todaysReturns.toStringAsFixed(0)}",
            changeText: "Today's refunded",
            isUp: true,
            icon: Icons.keyboard_return,
            iconColor: const Color(0xFF3B82F6),
            iconBgColor: const Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: StatCardWidget(
            title: "Active Clients",
            value: "$activeClients",
            changeText: "Clients without debt",
            isUp: true,
            icon: Icons.people_outline,
            iconColor: const Color(0xFFA855F7),
            iconBgColor: const Color(0xFF4C1D95),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: StatCardWidget(
            title: "Debt Clients",
            value: "$debtClients",
            changeText: "Clients with pending debt",
            isUp: false,
            icon: Icons.trending_down,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFF78350F),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(Map<String, dynamic> last7DaysSales) {
    final keys = last7DaysSales.keys.toList()..sort();
    List<FlSpot> spots = [];
    double maxY = 0.0;

    for (int i = 0; i < keys.length; i++) {
      final amount = last7DaysSales[keys[i]] as double;
      spots.add(FlSpot(i.toDouble(), amount));
      if (amount > maxY) maxY = amount;
    }

    // Add some padding to top of chart
    if (maxY == 0.0) maxY = 1000.0;
    else maxY = maxY * 1.2;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Revenue Overview",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Last 7 days performance",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: const [
                  Text("Week", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(width: 16),
                  Text("Month", style: TextStyle(color: Color(0xFF94A3B8))),
                  SizedBox(width: 16),
                  Text("Year", style: TextStyle(color: Color(0xFF94A3B8))),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF334155),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Color(0xFF94A3B8), fontSize: 12);
                        int index = value.toInt();
                        if (index >= 0 && index < keys.length) {
                          final dateStr = keys[index];
                          final date = DateTime.parse(dateStr);
                          final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
                          return SideTitleWidget(meta: meta, child: Text(weekday, style: style));
                        }
                        return SideTitleWidget(meta: meta, child: const Text(''));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(List<dynamic> transactions) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Transactions",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () => context.go('/transactions_history'),
                child: const Text(
                  "View All",
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: transactions.isEmpty 
            ? const Center(child: Text("No recent transactions", style: TextStyle(color: Colors.white54)))
            : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final action = tx['action_type'] ?? 'Unknown';
                final date = tx['created_at'] != null ? tx['created_at'].toString().split(' ')[0] : 'Today';
                final amount = tx['amount'] != null ? '\$${(tx['amount'] as num).toStringAsFixed(2)}' : '\$0.00';
                
                String status = 'completed';
                if (action == 'RETURN') status = 'returned';
                
                return _buildTransactionItem(
                  action, 
                  date, 
                  amount, 
                  status
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTransactionItem(String name, String desc, String amount, String status) {
    final isCompleted = status == 'completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.shopping_cart_outlined : Icons.keyboard_return_outlined, 
              color: isCompleted ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B), 
              size: 20
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLowStockAlerts(int lowStockCount, List<Product> lowStockProducts) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Low Stock Alerts",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (lowStockCount > 0) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "$lowStockCount",
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Products that need restocking",
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/inventory'),
                icon: const Icon(Icons.add),
                label: const Text('Restock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (lowStockProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No low stock products.", style: TextStyle(color: Colors.white54)),
            )
          else
            Row(
              children: lowStockProducts.map((p) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: _buildStockItem(p.name, p.stockQuantity <= 2 ? "Critical" : "Low Stock", p.stockQuantity, p.stockQuantity <= 2),
                  )
                );
              }).toList(),
            )
        ],
      ),
    );
  }

  Widget _buildStockItem(String name, String status, int left, bool isCritical) {
    final color = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.inventory_2_outlined, color: color, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$left left",
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../installments/data/app_data_store.dart';
import '../../core/db_models.dart';
import '../widgets/stat_card_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final store = AppDataStore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            store.productsNotifier,
            store.clientsNotifier,
            store.installmentsNotifier,
          ]),
          builder: (context, _) {
            final products     = store.products;
            final clients      = store.clients;
            final installments = store.installments;

            final totalRevenue    = installments.fold<double>(0, (s, p) => s + p.paidAmount);
            final pendingPayments = installments.fold<double>(0, (s, p) => s + p.remainingAmount);
            final lowStockCount   = products.where((p) => p.stockQuantity < 10).length;
            final totalSalesCount = installments.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatCards(totalRevenue, totalSalesCount, clients.length, pendingPayments),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildRevenueChart(installments),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 1,
                        child: _buildRecentTransactions(installments),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildLowStockAlerts(lowStockCount, products),
                ],
              ),
            );
          },
        ),
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
      ],
    );
  }

  Widget _buildStatCards(double revenue, int sales, int clients, double pending) {
    String fmt(double v) => v >= 1000 ? '\$${(v / 1000).toStringAsFixed(1)}K' : '\$${v.toStringAsFixed(0)}';
    return Row(
      children: [
        Expanded(
          child: StatCardWidget(
            title: "Total Revenue",
            value: fmt(revenue),
            changeText: "Lifetime total",
            isUp: true,
            icon: Icons.attach_money,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: StatCardWidget(
            title: "Total Sales",
            value: "$sales",
            changeText: "Active installment plans",
            isUp: true,
            icon: Icons.shopping_cart_outlined,
            iconColor: const Color(0xFF3B82F6),
            iconBgColor: const Color(0xFF1E3A8A).withOpacity(0.3),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: StatCardWidget(
            title: "Active Clients",
            value: "$clients",
            changeText: "Total in database",
            isUp: true,
            icon: Icons.people_outline,
            iconColor: const Color(0xFFA855F7),
            iconBgColor: const Color(0xFF4C1D95).withOpacity(0.3),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: StatCardWidget(
            title: "Pending Payments",
            value: fmt(pending),
            changeText: "Remaining to collect",
            isUp: false,
            icon: Icons.trending_up,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFF78350F).withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(List<DbInstallmentPlan> plans) {
    // Aggregating revenue for the chart (simplified for last 7 days)
    // In a real app, you'd group by date. For this demo, we'll map status to spots.
    final spots = [
      const FlSpot(0, 4200),
      const FlSpot(2, 3800),
      FlSpot(4, plans.isEmpty ? 0 : plans.length * 1000.0),
      FlSpot(6, plans.where((p) => p.status == 'completed').length * 2000.0),
      FlSpot(8, plans.where((p) => p.status == 'active').length * 1500.0),
      FlSpot(10, plans.fold<double>(0, (s, p) => s + p.paidAmount) / 10),
      const FlSpot(12, 5400),
    ];

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
                    "Real-time performance metrics",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
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
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Color(0xFF94A3B8), fontSize: 12);
                        Widget text;
                        switch (value.toInt()) {
                          case 0: text = const Text('Mon', style: style); break;
                          case 2: text = const Text('Tue', style: style); break;
                          case 4: text = const Text('Wed', style: style); break;
                          case 6: text = const Text('Thu', style: style); break;
                          case 8: text = const Text('Fri', style: style); break;
                          case 10: text = const Text('Sat', style: style); break;
                          case 12: text = const Text('Sun', style: style); break;
                          default: text = const Text(''); break;
                        }
                        return SideTitleWidget(meta: meta, child: text);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value >= 1000 ? '${(value/1000).toStringAsFixed(0)}K' : value.toStringAsFixed(0),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 12,
                minY: 0, maxY: 10000,
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

  Widget _buildRecentTransactions(List<DbInstallmentPlan> installments) {
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
            children: const [
              Text(
                "Recent Transactions",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "View All",
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: installments.isEmpty 
              ? Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  itemCount: installments.length > 4 ? 4 : installments.length,
                  itemBuilder: (context, i) {
                    final plan = installments[i];
                    return _buildTransactionItem(
                      plan.clientName,
                      "Invoice #${plan.invoiceId} • ${plan.status}",
                      "\$${plan.totalAmount.toStringAsFixed(2)}",
                      plan.status == 'completed' ? 'completed' : 'pending',
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
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF3B82F6), size: 20),
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

  Widget _buildLowStockAlerts(int lowStockCount, List<DbProduct> products) {
    final lowStockProducts = products.where((p) => p.stockQuantity < 10).toList();
    
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
            ],
          ),
          const SizedBox(height: 24),
          if (lowStockProducts.isEmpty)
             const Text("All items are well stocked.", style: TextStyle(color: Colors.white38))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: lowStockProducts.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildStockItem(p.name, p.stockQuantity < 5 ? "Critical" : "Low Stock", p.stockQuantity, p.stockQuantity < 5),
                )).toList(),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildStockItem(String name, String status, int left, bool isCritical) {
    final color = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    return Container(
      width: 220,
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
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

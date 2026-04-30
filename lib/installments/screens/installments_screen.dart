import 'package:flutter/material.dart';
import '../widgets/installment_stat_card.dart';
import '../widgets/payment_plan_card.dart';
import '../widgets/upcoming_payments_sidebar.dart';
import '../widgets/new_installment_plan_dialog.dart';

class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({Key? key}) : super(key: key);

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              _buildStatCards(),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main List
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Payment Plans",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildPaymentPlanList(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Sidebar
                  const Expanded(
                    flex: 1,
                    child: UpcomingPaymentsSidebar(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Installments System",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Track payment plans and manage installments",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 16,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const NewInstallmentPlanDialog(),
            );
          },
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('New Payment Plan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: const [
        Expanded(
          child: InstallmentStatCard(
            title: "Active Plans",
            value: "89",
            icon: Icons.calendar_today_outlined,
            color: Color(0xFF3B82F6),
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          child: InstallmentStatCard(
            title: "Collected This Month",
            value: "\$18.4K",
            icon: Icons.attach_money,
            color: Color(0xFF10B981),
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          child: InstallmentStatCard(
            title: "Pending",
            value: "\$12.5K",
            icon: Icons.error_outline,
            color: Color(0xFFF59E0B),
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          child: InstallmentStatCard(
            title: "Overdue",
            value: "\$2.3K",
            icon: Icons.trending_down,
            color: Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPlanList() {
    return Column(
      children: [
        PaymentPlanCard(
          clientName: "Sarah Smith",
          itemName: "iPhone 14 Pro",
          status: "Active",
          progress: 0.33,
          totalAmount: 1200,
          paidAmount: 400,
          remainingAmount: 800,
          monthlyAmount: 200,
          nextPaymentDate: "Apr 15, 2026",
          interestRate: 5,
          onViewDetails: () {},
          onRecordPayment: () {},
        ),
        PaymentPlanCard(
          clientName: "David Brown",
          itemName: "MacBook Air M2 + Accessories",
          status: "Active",
          progress: 0.50,
          totalAmount: 3200,
          paidAmount: 1600,
          remainingAmount: 1600,
          monthlyAmount: 400,
          nextPaymentDate: "Apr 10, 2026",
          interestRate: 4,
          onViewDetails: () {},
          onRecordPayment: () {},
        ),
        PaymentPlanCard(
          clientName: "Emma Wilson",
          itemName: "Samsung Galaxy S23 Ultra",
          status: "Overdue",
          progress: 0.20,
          totalAmount: 1500,
          paidAmount: 300,
          remainingAmount: 1200,
          monthlyAmount: 150,
          nextPaymentDate: "Apr 8, 2026",
          interestRate: 6,
          onViewDetails: () {},
          onRecordPayment: () {},
        ),
      ],
    );
  }
}

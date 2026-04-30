import 'package:flutter/material.dart';

class UpcomingPaymentsSidebar extends StatelessWidget {
  const UpcomingPaymentsSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: const [
            Icon(Icons.calendar_today_outlined, color: Color(0xFF94A3B8), size: 20),
            SizedBox(width: 8),
            Text(
              "Upcoming Payments",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // List of Upcoming Payments
        _buildUpcomingItem(
          name: "Emma Wilson",
          dueDate: "Due: Apr 8",
          amount: "\$150",
          isOverdue: true,
          buttonText: "Collect",
        ),
        _buildUpcomingItem(
          name: "David Brown",
          dueDate: "Due: Apr 10",
          amount: "\$400",
          isOverdue: false,
          buttonText: "Remind",
        ),
        _buildUpcomingItem(
          name: "Sarah Smith",
          dueDate: "Due: Apr 15",
          amount: "\$200",
          isOverdue: false,
          buttonText: "Remind",
        ),
        _buildUpcomingItem(
          name: "John Doe",
          dueDate: "Due: Apr 20",
          amount: "\$350",
          isOverdue: false,
          buttonText: "Remind",
        ),

        const SizedBox(height: 32),

        // Monthly Overview Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Monthly Overview",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        "April 2026",
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildOverviewRow("Expected", "\$24,500", Colors.white),
              const SizedBox(height: 12),
              _buildOverviewRow("Collected", "\$18,400", const Color(0xFF10B981)),
              const SizedBox(height: 12),
              _buildOverviewRow("Remaining", "\$6,100", const Color(0xFFF59E0B)),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: 0.75,
                backgroundColor: const Color(0xFF334155),
                color: const Color(0xFF3B82F6),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "75% collection rate",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingItem({
    required String name,
    required String dueDate,
    required String amount,
    required bool isOverdue,
    required String buttonText,
  }) {
    final Color highlightColor = isOverdue ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverdue ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              if (isOverdue)
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dueDate,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: highlightColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(buttonText, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}

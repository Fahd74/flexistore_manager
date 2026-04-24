import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_shell.dart';
import '../auth/screens/login_screen.dart';

import '../dashboard/screens/dashboard_screen.dart';

// Placeholder widgets for modules
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('POS Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Clients Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

class InstallmentsScreen extends StatelessWidget {
  const InstallmentsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Installments Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Inventory Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Transactions Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

class ReturnsScreen extends StatelessWidget {
  const ReturnsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Returns Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Audit Module', style: TextStyle(color: Colors.white, fontSize: 24)),
  );
}

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/pos', builder: (context, state) => const PosScreen()),
        GoRoute(path: '/clients', builder: (context, state) => const ClientsScreen()),
        GoRoute(
          path: '/installments',
          builder: (context, state) => const InstallmentsScreen(),
        ),
        GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen()),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsScreen(),
        ),
        GoRoute(path: '/returns', builder: (context, state) => const ReturnsScreen()),
        GoRoute(path: '/audit', builder: (context, state) => const AuditScreen()),
      ],
    ),
  ],
);

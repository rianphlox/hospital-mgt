import 'package:flutter/material.dart';
import '../../models/user_models.dart';
import 'cashier_dashboard.dart';
import 'inventory_screen.dart';

class CashierMainScreen extends StatefulWidget {
  final UserProfile profile;

  const CashierMainScreen({
    super.key,
    required this.profile,
  });

  @override
  State<CashierMainScreen> createState() => _CashierMainScreenState();
}

class _CashierMainScreenState extends State<CashierMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE7E5E4)),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF10B981),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.receipt_long),
                text: 'Billing',
              ),
              Tab(
                icon: Icon(Icons.inventory),
                text: 'Inventory',
              ),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              CashierBillingTab(profile: widget.profile),
              InventoryScreen(profile: widget.profile),
            ],
          ),
        ),
      ],
    );
  }
}
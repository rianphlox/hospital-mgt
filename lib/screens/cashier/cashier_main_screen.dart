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
    return Container(
      color: Colors.white,
      child: Column(
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
              labelColor: const Color(0xFF10B981), // Emerald-500
              unselectedLabelColor: const Color(0xFFA8A29E), // Stone-400
              indicatorColor: const Color(0xFF10B981),
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
              padding: const EdgeInsets.only(top: 8),
              tabs: const [
                Tab(
                  height: 70,
                  icon: Icon(Icons.receipt_long_rounded, size: 28),
                  text: 'Billing',
                ),
                Tab(
                  height: 70,
                  icon: Icon(Icons.inventory_2_rounded, size: 28),
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
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // For now, just show a message - we'll connect to AuthProvider next
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logout button working! Will connect to auth...'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
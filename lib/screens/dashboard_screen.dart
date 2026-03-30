import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/user_models.dart';
import 'nurse/nurse_dashboard.dart';
import 'cashier/cashier_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'patient_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize data loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, DataProvider>(
      builder: (context, authProvider, dataProvider, _) {
        final profile = authProvider.profile;

        if (profile == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5), // Emerald-100
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_hospital,
                    color: Color(0xFF10B981), // Emerald-500
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CrownLog',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${profile.role.name.toUpperCase()} • ${profile.ward ?? 'Hospital'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF78716C), // Stone-500
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            profile.email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78716C),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        print('PopupMenu selected: $value'); // Debug print
                        if (value == 'logout') {
                          _showLogoutDialog(context, authProvider);
                        } else if (value == 'patient_history') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PatientHistoryScreen(),
                            ),
                          );
                        }
                      },
                      // Add this to make it more obvious it's tappable
                      tooltip: 'Account menu',
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'patient_history',
                          child: Row(
                            children: [
                              Icon(Icons.history, color: Color(0xFF059669)),
                              SizedBox(width: 8),
                              Text('Patient History'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Sign Out'),
                            ],
                          ),
                        ),
                      ],
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFFF87171), // Red-400
                        child: Text(
                          profile.name.isNotEmpty
                              ? profile.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: _buildBodyForRole(profile.role, profile),
        );
      },
    );
  }

  Widget _buildBodyForRole(UserRole role, UserProfile profile) {
    switch (role) {
      case UserRole.nurse:
        return const NurseDashboard();
      case UserRole.cashier:
        return CashierDashboard(profile: profile);
      case UserRole.admin:
        return AdminDashboard(profile: profile);
    }
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                authProvider.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}
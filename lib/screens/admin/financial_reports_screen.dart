import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/data_provider.dart';
import '../../models/patient_models.dart';
import '../../models/user_models.dart';

class FinancialReportsScreen extends StatefulWidget {
  final UserProfile adminProfile;

  const FinancialReportsScreen({
    super.key,
    required this.adminProfile,
  });

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Financial Reports',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF78716C),
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Revenue'),
            Tab(text: 'Payments'),
            Tab(text: 'Outstanding'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Range Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE7E5E4)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF78716C)),
                const SizedBox(width: 8),
                Text(
                  'Period: ${_formatDateRange()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78716C),
                  ),
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildRevenueTab(),
                _buildPaymentsTab(),
                _buildOutstandingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final financialData = _calculateFinancialOverview(dataProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key Metrics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Total Revenue',
                      _formatCurrency(financialData['totalRevenue']!),
                      Icons.trending_up,
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'Total Payments',
                      financialData['totalPayments'].toString(),
                      Icons.payment,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Outstanding',
                      _formatCurrency(financialData['outstandingAmount']!),
                      Icons.account_balance_wallet,
                      const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'Collection Rate',
                      '${financialData['collectionRate']!.toStringAsFixed(1)}%',
                      Icons.percent,
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Daily Revenue Chart Placeholder
              _buildChartCard(
                'Daily Revenue Trend',
                Icons.show_chart,
                _buildDailyRevenueChart(dataProvider),
              ),
              const SizedBox(height: 16),

              // Payment Methods Summary
              _buildChartCard(
                'Payment Methods',
                Icons.pie_chart,
                _buildPaymentMethodsSummary(dataProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueTab() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final treatments = _getFilteredTreatments(dataProvider);
        final revenueByDay = _calculateDailyRevenue(treatments);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Revenue Breakdown',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Revenue by Day
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7E5E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Revenue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (revenueByDay.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No revenue data for selected period',
                            style: TextStyle(color: Color(0xFF78716C)),
                          ),
                        ),
                      )
                    else
                      ...revenueByDay.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy').format(entry.key),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatCurrency(entry.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final payments = _getFilteredPayments(dataProvider);
        final paymentsByMethod = _groupPaymentsByMethod(payments);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Payment Methods Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7E5E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Methods',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...paymentsByMethod.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getPaymentMethodIcon(entry.key),
                                size: 20,
                                color: const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatCurrency(entry.value['amount']!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              Text(
                                '${entry.value['count']} transactions',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF78716C),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Recent Payments
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7E5E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Payments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (payments.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No payments found for selected period',
                            style: TextStyle(color: Color(0xFF78716C)),
                          ),
                        ),
                      )
                    else
                      ...payments.take(10).map((payment) => _buildPaymentRow(payment)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOutstandingTab() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final outstandingBalances = _calculateOutstandingBalances(dataProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Outstanding Balances',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              if (outstandingBalances.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No outstanding balances found',
                      style: TextStyle(color: Color(0xFF78716C)),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE7E5E4)),
                  ),
                  child: Column(
                    children: outstandingBalances.map((balance) => _buildOutstandingRow(balance)).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF78716C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, IconData icon, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          chart,
        ],
      ),
    );
  }

  Widget _buildDailyRevenueChart(DataProvider dataProvider) {
    final treatments = _getFilteredTreatments(dataProvider);
    final dailyRevenue = _calculateDailyRevenue(treatments);

    if (dailyRevenue.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No revenue data available',
            style: TextStyle(color: Color(0xFF78716C)),
          ),
        ),
      );
    }

    final maxRevenue = dailyRevenue.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: dailyRevenue.entries.take(7).map((entry) {
        final percentage = maxRevenue > 0 ? (entry.value / maxRevenue) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  DateFormat('MMM dd').format(entry.key),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(
                  _formatCurrency(entry.value),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethodsSummary(DataProvider dataProvider) {
    final payments = _getFilteredPayments(dataProvider);
    final paymentsByMethod = _groupPaymentsByMethod(payments);

    if (paymentsByMethod.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No payment data available',
            style: TextStyle(color: Color(0xFF78716C)),
          ),
        ),
      );
    }

    final totalAmount = paymentsByMethod.values.fold(0, (sum, data) => sum + data['amount']!);

    return Column(
      children: paymentsByMethod.entries.map((entry) {
        final percentage = totalAmount > 0 ? (entry.value['amount']! / totalAmount * 100) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                _getPaymentMethodIcon(entry.key),
                size: 20,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.key),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentRow(Payment payment) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getPaymentMethodIcon(payment.paymentMethod),
            size: 16,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.cashierName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(payment.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78716C),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(payment.amount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingRow(Map<String, dynamic> balance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance['patientName'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ID: ${balance['patientId']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78716C),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(balance['outstandingAmount']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444),
                ),
              ),
              Text(
                'Billed: ${_formatCurrency(balance['totalBilled'])}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF78716C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  String _formatDateRange() {
    if (_selectedDateRange == null) return 'All Time';
    final start = DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start);
    final end = DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end);
    return '$start - $end';
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
      case 'pos':
        return Icons.credit_card;
      case 'transfer':
      case 'bank transfer':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  List<Treatment> _getFilteredTreatments(DataProvider dataProvider) {
    return dataProvider.treatments.where((treatment) {
      if (_selectedDateRange == null) return true;
      final treatmentDate = treatment.pricedAt ?? treatment.timestamp;
      return treatmentDate.isAfter(_selectedDateRange!.start) &&
             treatmentDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    }).where((treatment) => treatment.pricingStatus == TreatmentPricingStatus.billed).toList();
  }

  List<Payment> _getFilteredPayments(DataProvider dataProvider) {
    return dataProvider.payments.where((payment) {
      if (_selectedDateRange == null) return true;
      return payment.timestamp.isAfter(_selectedDateRange!.start) &&
             payment.timestamp.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    }).toList();
  }

  Map<String, int> _calculateFinancialOverview(DataProvider dataProvider) {
    final treatments = _getFilteredTreatments(dataProvider);
    final payments = _getFilteredPayments(dataProvider);

    final totalRevenue = treatments.fold(0, (sum, treatment) => sum + treatment.totalCharge);
    final totalPayments = payments.length;
    final totalPaid = payments.fold(0, (sum, payment) => sum + payment.amount);
    final outstandingAmount = totalRevenue - totalPaid;
    final collectionRate = totalRevenue > 0 ? (totalPaid / totalRevenue * 100) : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalPayments': totalPayments,
      'outstandingAmount': outstandingAmount,
      'collectionRate': collectionRate.round(),
    };
  }

  Map<DateTime, int> _calculateDailyRevenue(List<Treatment> treatments) {
    final dailyRevenue = <DateTime, int>{};

    for (final treatment in treatments) {
      final date = DateTime(
        treatment.timestamp.year,
        treatment.timestamp.month,
        treatment.timestamp.day,
      );
      dailyRevenue[date] = (dailyRevenue[date] ?? 0) + treatment.totalCharge;
    }

    return Map.fromEntries(
      dailyRevenue.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  Map<String, Map<String, int>> _groupPaymentsByMethod(List<Payment> payments) {
    final grouped = <String, Map<String, int>>{};

    for (final payment in payments) {
      if (!grouped.containsKey(payment.paymentMethod)) {
        grouped[payment.paymentMethod] = {'amount': 0, 'count': 0};
      }
      grouped[payment.paymentMethod]!['amount'] = grouped[payment.paymentMethod]!['amount']! + payment.amount;
      grouped[payment.paymentMethod]!['count'] = grouped[payment.paymentMethod]!['count']! + 1;
    }

    return grouped;
  }

  List<Map<String, dynamic>> _calculateOutstandingBalances(DataProvider dataProvider) {
    final patients = dataProvider.patients;
    final treatments = dataProvider.treatments.where(
      (t) => t.pricingStatus == TreatmentPricingStatus.billed,
    );
    final payments = dataProvider.payments;

    final outstandingBalances = <Map<String, dynamic>>[];

    for (final patient in patients) {
      final patientTreatments = treatments.where((t) => t.patientId == patient.id);
      final patientPayments = payments.where((p) => p.patientId == patient.id);

      final totalBilled = patientTreatments.fold(0, (sum, t) => sum + t.totalCharge);
      final totalPaid = patientPayments.fold(0, (sum, p) => sum + p.amount);
      final outstanding = totalBilled - totalPaid;

      if (outstanding > 0) {
        outstandingBalances.add({
          'patientId': patient.id,
          'patientName': patient.name,
          'totalBilled': totalBilled,
          'totalPaid': totalPaid,
          'outstandingAmount': outstanding,
        });
      }
    }

    outstandingBalances.sort((a, b) => b['outstandingAmount'].compareTo(a['outstandingAmount']));
    return outstandingBalances;
  }
}
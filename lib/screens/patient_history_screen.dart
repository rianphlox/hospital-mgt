import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/patient_models.dart';
import '../providers/data_provider.dart';
import '../widgets/notification_center.dart';

enum DateRange {
  today,
  yesterday,
  last7Days,
  last14Days,
  last30Days,
  last3Months,
  last6Months,
  lastYear,
  custom,
}

extension DateRangeExtension on DateRange {
  String get displayName {
    switch (this) {
      case DateRange.today:
        return 'Today';
      case DateRange.yesterday:
        return 'Yesterday';
      case DateRange.last7Days:
        return 'Last 7 Days';
      case DateRange.last14Days:
        return 'Last 14 Days';
      case DateRange.last30Days:
        return 'Last 30 Days';
      case DateRange.last3Months:
        return 'Last 3 Months';
      case DateRange.last6Months:
        return 'Last 6 Months';
      case DateRange.lastYear:
        return 'Last Year';
      case DateRange.custom:
        return 'Custom Range';
    }
  }

  IconData get icon {
    switch (this) {
      case DateRange.today:
        return Icons.today;
      case DateRange.yesterday:
        return Icons.history;
      case DateRange.last7Days:
        return Icons.date_range;
      case DateRange.last14Days:
        return Icons.date_range;
      case DateRange.last30Days:
        return Icons.calendar_month;
      case DateRange.last3Months:
        return Icons.calendar_view_month;
      case DateRange.last6Months:
        return Icons.calendar_view_week;
      case DateRange.lastYear:
        return Icons.event;
      case DateRange.custom:
        return Icons.tune;
    }
  }

  DateTimeRange get dateTimeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case DateRange.today:
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case DateRange.yesterday:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 1)),
          end: today,
        );
      case DateRange.last7Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 7)),
          end: today.add(const Duration(days: 1)),
        );
      case DateRange.last14Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 14)),
          end: today.add(const Duration(days: 1)),
        );
      case DateRange.last30Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 30)),
          end: today.add(const Duration(days: 1)),
        );
      case DateRange.last3Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 3, now.day),
          end: today.add(const Duration(days: 1)),
        );
      case DateRange.last6Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 6, now.day),
          end: today.add(const Duration(days: 1)),
        );
      case DateRange.lastYear:
        return DateTimeRange(
          start: DateTime(now.year - 1, now.month, now.day),
          end: today.add(const Duration(days: 1)),
        );
      case DateRange.custom:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 30)),
          end: today.add(const Duration(days: 1)),
        );
    }
  }
}

class PatientHistoryScreen extends StatefulWidget {
  final Patient? specificPatient;
  final String title;

  const PatientHistoryScreen({
    super.key,
    this.specificPatient,
    this.title = 'Patient History',
  });

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen>
    with TickerProviderStateMixin {
  DateRange _selectedRange = DateRange.last30Days;
  DateTimeRange? _customRange;
  String _searchQuery = '';
  PatientStatus? _statusFilter;
  bool _showFilters = false;
  TabController? _tabController;

  final List<String> _tabLabels = ['All Activity', 'Treatments', 'Payments', 'Admissions'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _loadHistoryData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _loadHistoryData() {
    // Load patients based on selected date range
    // This would integrate with your data provider
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Search button
          IconButton(
            onPressed: _showSearchDialog,
            icon: const Icon(Icons.search),
          ),
          // Filter toggle
          IconButton(
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: _showFilters ? const Color(0xFF10B981) : null,
            ),
          ),
          // Notifications
          const NotificationBell(),
          const SizedBox(width: 8),
        ],
        bottom: _showFilters ? _buildFilterSection() : null,
      ),
      body: Column(
        children: [
          // Quick stats header
          _buildQuickStatsHeader(),

          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFF10B981),
              tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllActivityTab(),
                _buildTreatmentsTab(),
                _buildPaymentsTab(),
                _buildAdmissionsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportHistory,
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.file_download),
        label: const Text('Export'),
      ),
    );
  }

  PreferredSizeWidget _buildFilterSection() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date range selector
            Row(
              children: [
                const Icon(Icons.date_range, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                const Text(
                  'Time Period:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: DateRange.values.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final range = DateRange.values[index];
                  final isSelected = _selectedRange == range;

                  return FilterChip(
                    selected: isSelected,
                    onSelected: (selected) => _selectDateRange(range),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(range.icon, size: 14),
                        const SizedBox(width: 4),
                        Text(_getDisplayName(range)),
                      ],
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF10B981),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsHeader() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final patients = _getFilteredPatients(dataProvider.patients);
        final activeCount = patients.where((p) => p.status == PatientStatus.active).length;
        final dischargedCount = patients.where((p) => p.status == PatientStatus.discharged).length;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Patients',
                  patients.length.toString(),
                  Icons.people,
                  Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  activeCount.toString(),
                  Icons.local_hospital,
                  Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Discharged',
                  dischargedCount.toString(),
                  Icons.check_circle,
                  Colors.orange.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAllActivityTab() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final patients = _getFilteredPatients(dataProvider.patients);

        if (patients.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No Activity Found',
            message: 'No patient activity found for the selected time period.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final patient = patients[index];
            return _buildPatientActivityCard(patient);
          },
        );
      },
    );
  }

  Widget _buildTreatmentsTab() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        // This would load and display treatments within the date range
        // For now, showing placeholder
        return _buildEmptyState(
          icon: Icons.medical_services,
          title: 'Treatments',
          message: 'Treatment history will be displayed here based on the selected date range.',
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        // This would load and display payments within the date range
        return _buildEmptyState(
          icon: Icons.payment,
          title: 'Payments',
          message: 'Payment history will be displayed here based on the selected date range.',
        );
      },
    );
  }

  Widget _buildAdmissionsTab() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final patients = _getFilteredPatients(dataProvider.patients);
        final admissions = patients.where((p) => _isWithinDateRange(p.createdAt)).toList();

        if (admissions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.hotel,
            title: 'No Admissions',
            message: 'No patient admissions found for the selected time period.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: admissions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final patient = admissions[index];
            return _buildAdmissionCard(patient);
          },
        );
      },
    );
  }

  Widget _buildPatientActivityCard(Patient patient) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: patient.status == PatientStatus.active
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  child: Text(
                    patient.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: patient.status == PatientStatus.active
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Admission #${patient.admissionNumber}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: patient.status == PatientStatus.active
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    patient.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: patient.status == PatientStatus.active
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.calendar_today, _formatDate(patient.createdAt)),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.location_on, patient.ward),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.person, patient.type.displayName),
              ],
            ),
            if (patient.dischargedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.exit_to_app, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Discharged: ${_formatDate(patient.dischargedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdmissionCard(Patient patient) {
    final daysSinceAdmission = DateTime.now().difference(patient.createdAt).inDays;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.hotel,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Admitted ${_formatDate(patient.createdAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Ward: ${patient.ward} • ${patient.type.displayName}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '$daysSinceAdmission',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  daysSinceAdmission == 1 ? 'day' : 'days',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Event handlers and helper methods

  void _selectDateRange(DateRange range) async {
    if (range == DateRange.custom) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final defaultRange = DateTimeRange(
        start: today.subtract(const Duration(days: 30)),
        end: today,
      );

      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: today,
        initialDateRange: _customRange ?? defaultRange,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF10B981),
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _selectedRange = range;
          _customRange = picked;
        });
        _loadHistoryData();
      }
    } else {
      setState(() {
        _selectedRange = range;
        _customRange = null;
      });
      _loadHistoryData();
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Patients'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter patient name or admission number...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadHistoryData();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportHistory() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Request storage permissions for Android
      if (Platform.isAndroid) {
        bool hasPermission = false;

        // Check Android version and request appropriate permissions
        if (await Permission.manageExternalStorage.isGranted) {
          hasPermission = true;
        } else {
          // For Android 11+ (API 30+), request MANAGE_EXTERNAL_STORAGE
          final manageStorageResult = await Permission.manageExternalStorage.request();
          if (manageStorageResult.isGranted) {
            hasPermission = true;
          } else {
            // Fallback: try regular storage permission for older Android versions
            final storageResult = await Permission.storage.request();
            hasPermission = storageResult.isGranted;
          }
        }

        if (!hasPermission) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Storage permission needed to export data'),
                    Text('Please allow "All files access" in Settings',
                         style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      final dataProvider = context.read<DataProvider>();
      final filteredPatients = _getFilteredPatients(dataProvider.patients);

      if (filteredPatients.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No patient data to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Generate CSV content
      final StringBuffer csvContent = StringBuffer();
      csvContent.writeln('Patient Name,Admission Number,Ward,Type,Status,Admission Date,Discharge Date');

      for (final patient in filteredPatients) {
        csvContent.writeln([
          '"${patient.name}"',
          patient.admissionNumber,
          patient.ward,
          patient.type.displayName,
          patient.status.name,
          DateFormat('yyyy-MM-dd').format(patient.createdAt),
          patient.dischargedAt != null
            ? DateFormat('yyyy-MM-dd').format(patient.dischargedAt!)
            : 'N/A',
        ].join(','));
      }

      // Save to accessible location
      String fileName = 'PatientHistory_${_getExportDateRange()}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      File? savedFile;

      try {
        if (Platform.isAndroid) {
          // Try Downloads folder first
          String downloadsPath = '/storage/emulated/0/Download';
          Directory downloadsDirectory = Directory(downloadsPath);

          if (await downloadsDirectory.exists()) {
            savedFile = File('$downloadsPath/$fileName');
            await savedFile.writeAsString(csvContent.toString());

            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('✅ Patient history exported!'),
                      Text('Exported ${filteredPatients.length} patient records',
                           style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          } else {
            throw Exception('Downloads folder not accessible');
          }
        } else {
          // iOS: Save to Documents directory
          Directory documentsDirectory = await getApplicationDocumentsDirectory();
          savedFile = File('${documentsDirectory.path}/$fileName');
          await savedFile.writeAsString(csvContent.toString());

          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('✅ Exported ${filteredPatients.length} records to Files app'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        }
      } catch (storageError) {
        // Fallback: Save to app directory
        Directory appDir = await getApplicationDocumentsDirectory();
        savedFile = File('${appDir.path}/$fileName');
        await savedFile.writeAsString(csvContent.toString());

        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('⚠️ Data exported to app storage - use share feature to access'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getExportDateRange() {
    if (_selectedRange == DateRange.custom && _customRange != null) {
      final start = DateFormat('MMM_dd').format(_customRange!.start);
      final end = DateFormat('MMM_dd_yyyy').format(_customRange!.end);
      return '${start}_to_$end';
    }
    return _selectedRange.displayName.replaceAll(' ', '_');
  }

  List<Patient> _getFilteredPatients(List<Patient> allPatients) {
    var filtered = allPatients.where((patient) {
      // Date range filter
      if (!_isWithinDateRange(patient.createdAt)) return false;

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!patient.name.toLowerCase().contains(query) &&
            !patient.admissionNumber.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter != null && patient.status != _statusFilter) {
        return false;
      }

      return true;
    }).toList();

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  bool _isWithinDateRange(DateTime date) {
    final range = _customRange ?? _selectedRange.dateTimeRange;
    return date.isAfter(range.start) && date.isBefore(range.end);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _getDisplayName(DateRange range) {
    if (range == DateRange.custom && _customRange != null) {
      final start = DateFormat('MMM dd').format(_customRange!.start);
      final end = DateFormat('MMM dd, yyyy').format(_customRange!.end);
      return '$start - $end';
    }
    return range.displayName;
  }
}
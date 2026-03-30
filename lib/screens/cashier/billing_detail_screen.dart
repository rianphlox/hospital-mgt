import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
// import 'package:downloads_path_provider_28/downloads_path_provider_28.dart'; // Removed due to namespace issues
import 'dart:io';
import '../../models/patient_models.dart';
import '../../models/user_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../widgets/record_payment_dialog.dart';
import '../../widgets/debt_forgiveness_dialog.dart';
import '../../widgets/discharge_patient_dialog.dart';

class BillingDetailScreen extends StatefulWidget {
  final Patient patient;

  const BillingDetailScreen({
    super.key,
    required this.patient,
  });

  @override
  State<BillingDetailScreen> createState() => _BillingDetailScreenState();
}

class _BillingDetailScreenState extends State<BillingDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load treatments and payments for this patient
    final dataProvider = context.read<DataProvider>();
    dataProvider.loadTreatments(widget.patient.id);
    dataProvider.loadPayments(widget.patient.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Billing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer2<DataProvider, AuthProvider>(
        builder: (context, dataProvider, authProvider, _) {
          final treatments = dataProvider.treatments;
          final payments = dataProvider.payments;
          final profile = authProvider.profile!;

          // Only include priced treatments for billing
          final pricedTreatments = treatments.where(
            (treatment) => treatment.pricingStatus == TreatmentPricingStatus.priced ||
                          treatment.pricingStatus == TreatmentPricingStatus.billed,
          ).toList();

          final totalBilled = pricedTreatments.fold<int>(
            0,
            (sum, treatment) => sum + treatment.totalCharge,
          );
          final totalPaid = payments.fold<int>(
            0,
            (sum, payment) => sum + payment.amount,
          );
          final balance = totalBilled - totalPaid;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Patient summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF10B981),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.patient.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: widget.patient.type == PatientType.inPatient
                                              ? const Color(0xFFDEF7EC)
                                              : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          widget.patient.type.displayName,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: widget.patient.type == PatientType.inPatient
                                                ? const Color(0xFF065F46)
                                                : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '${widget.patient.admissionNumber} • ${widget.patient.ward}',
                                          style: const TextStyle(
                                            color: Color(0xFF78716C),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            _buildSummaryCard(
                              'Total Billed',
                              _formatCurrency(totalBilled),
                              const Color(0xFFFAFAF9),
                              const Color(0xFF1C1917),
                            ),
                            const SizedBox(width: 12),
                            _buildSummaryCard(
                              'Total Paid',
                              _formatCurrency(totalPaid),
                              const Color(0xFFD1FAE5),
                              const Color(0xFF059669),
                            ),
                            const SizedBox(width: 12),
                            _buildSummaryCard(
                              'Balance',
                              _formatCurrency(balance),
                              balance > 0
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFD1FAE5),
                              balance > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF059669),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment actions
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showRecordPaymentDialog(context, profile),
                        icon: const Icon(Icons.add),
                        label: const Text('Record Payment'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    // Debt forgiveness button (only for admin with outstanding balance)
                    if (profile.role == UserRole.admin &&
                        widget.patient.outstandingBalance > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showDebtForgivenessDialog(context, profile),
                          icon: const Icon(Icons.money_off),
                          label: const Text('Forgive Debt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],

                    // Discharge button (only for cashiers and admins when patient has no outstanding balance)
                    if ((profile.role == UserRole.admin || profile.role == UserRole.cashier) &&
                        widget.patient.status == PatientStatus.active) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showDischargeDialog(context, profile),
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Discharge Patient'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Itemized bill
                Card(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEFEFD),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.list_alt,
                              color: Color(0xFF78716C),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Itemized Bill',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _generateBillPDF(),
                              icon: const Icon(Icons.print, size: 16),
                              label: const Text(
                                'Export PDF',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 400,
                        child: pricedTreatments.isEmpty
                            ? _buildEmptyBill()
                            : Column(
                                children: [
                                  // Summary info for cashier
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF0FDF4),
                                      border: Border(
                                        bottom: BorderSide(color: Color(0xFFE7E5E4)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Color(0xFF059669),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Showing ${pricedTreatments.length} priced treatment${pricedTreatments.length != 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            color: Color(0xFF065F46),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (treatments.length > pricedTreatments.length) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${treatments.length - pricedTreatments.length} pending pricing',
                                              style: const TextStyle(
                                                color: Color(0xFFEAB308),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Treatment list
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.all(24),
                                      itemCount: pricedTreatments.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(height: 32),
                                      itemBuilder: (context, index) {
                                        final treatment = pricedTreatments[index];
                                        return _buildTreatmentSection(treatment);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recent payments
                if (payments.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                color: Color(0xFF78716C),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Recent Payments',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...payments.take(3).map((payment) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildPaymentItem(payment),
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatCurrency(int amount) {
    // Format large numbers with appropriate suffixes and commas
    if (amount >= 1000000) {
      double millions = amount / 1000000.0;
      return '₦${millions.toStringAsFixed(millions == millions.truncate() ? 0 : 1)}M';
    } else if (amount >= 1000) {
      double thousands = amount / 1000.0;
      return '₦${thousands.toStringAsFixed(thousands == thousands.truncate() ? 0 : 1)}K';
    } else {
      return '₦$amount';
    }
  }

  String _formatFullCurrency(int amount) {
    // Format with commas for full display
    return '₦${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  Widget _buildSummaryCard(String label, String amount, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA8A29E),
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBill() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Color(0xFFA8A29E),
          ),
          SizedBox(height: 16),
          Text(
            'No treatments billed yet',
            style: TextStyle(
              color: Color(0xFFA8A29E),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentSection(Treatment treatment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(treatment.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA8A29E),
                      letterSpacing: 1,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.medical_services,
                        size: 14,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Administered by: ${treatment.nurseName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF78716C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _formatFullCurrency(treatment.totalCharge),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1917),
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...treatment.items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEFEFD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: Color(0xFF1C1917),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: ${item.quantity} × ${_formatFullCurrency(item.unitPrice)} each',
                          style: const TextStyle(
                            color: Color(0xFF78716C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatFullCurrency(item.unitPrice * item.quantity),
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildPaymentItem(Payment payment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatFullCurrency(payment.amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
                Text(
                  payment.paymentMethod.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF78716C),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM d').format(payment.timestamp),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF78716C),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => RecordPaymentDialog(
        patient: widget.patient,
        profile: profile,
      ),
    );
  }

  void _showDebtForgivenessDialog(BuildContext context, UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => DebtForgivenessDialog(
        patient: widget.patient,
        profile: profile,
      ),
    );
  }

  void _showDischargeDialog(BuildContext context, UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => DischargePatientDialog(
        patient: widget.patient,
        adminProfile: profile,
        onSuccess: () {
          // Refresh data and go back
          final dataProvider = context.read<DataProvider>();
          dataProvider.refreshStats();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _generateBillPDF() async {
    // Get references before any async operations
    final dataProvider = context.read<DataProvider>();
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
                    Text('Storage permission needed to save receipt'),
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
      final treatments = dataProvider.treatments;
      final payments = dataProvider.payments;

      // Only include priced treatments in PDF
      final pricedTreatments = treatments.where(
        (treatment) => treatment.pricingStatus == TreatmentPricingStatus.priced ||
                      treatment.pricingStatus == TreatmentPricingStatus.billed,
      ).toList();

      final totalBilled = pricedTreatments.fold<int>(
        0,
        (sum, treatment) => sum + treatment.totalCharge,
      );
      final totalPaid = payments.fold<int>(
        0,
        (sum, payment) => sum + payment.amount,
      );
      final balance = totalBilled - totalPaid;

      // Load fonts that support Unicode (Naira symbol)
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      final fontBoldData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(fontBoldData);

      // Create PDF document
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: ttf,
            bold: ttfBold,
          ),
          build: (pw.Context context) {
            return [
              // Header with Logo
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 2),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        // Crown Logo
                        pw.Container(
                          width: 50,
                          height: 50,
                          margin: const pw.EdgeInsets.only(right: 16),
                          decoration: pw.BoxDecoration(
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(25)),
                            border: pw.Border.all(width: 3, color: PdfColors.grey),
                            color: PdfColors.grey100,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'CROWN',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'THE CROWN HOSPITAL LTD',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Patient Billing Statement',
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'),
                        pw.Text('Bill ID: #${widget.patient.admissionNumber}'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Patient Info
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Patient Information',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Name: ${widget.patient.name}'),
                              pw.Text('Admission No: ${widget.patient.admissionNumber}'),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Ward: ${widget.patient.ward}'),
                              pw.Text('Type: ${widget.patient.type.displayName}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Billing Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'Total Billed',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(_formatPdfCurrency(totalBilled)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Total Paid',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(_formatPdfCurrency(totalPaid)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Balance',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          _formatPdfCurrency(balance),
                          style: pw.TextStyle(
                            color: balance > 0 ? PdfColors.red : PdfColors.green,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Treatment Details
              if (pricedTreatments.isNotEmpty) ...[
                pw.Text(
                  'Treatment Details',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),

                ...pricedTreatments.map((treatment) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                DateFormat('MMM d, yyyy').format(treatment.timestamp),
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                              pw.Text('Nurse: ${treatment.nurseName}'),
                            ],
                          ),
                          pw.Text(
                            _formatPdfCurrency(treatment.totalCharge),
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              ),
                            ],
                          ),
                          ...treatment.items.map((item) => pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(item.name),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('${item.quantity}'),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(_formatPdfCurrency(item.unitPrice)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(_formatPdfCurrency(item.totalPrice)),
                              ),
                            ],
                          )),
                        ],
                      ),
                    ],
                  ),
                )),
              ],

              // Payment History
              if (payments.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Payment History',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Method', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Cashier', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...payments.map((payment) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(DateFormat('MMM d, yyyy').format(payment.timestamp)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(_formatPdfCurrency(payment.amount)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(payment.paymentMethod.toUpperCase()),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(payment.cashierName),
                        ),
                      ],
                    )),
                  ],
                ),
              ],

              pw.SizedBox(height: 30),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide()),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Generated on ${DateFormat('MMM d, yyyy - h:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ];
          },
        ),
      );

      // Save PDF to easily accessible Downloads folder (Android) or Documents (iOS)
      String fileName = 'CrownLog_Bill_${widget.patient.admissionNumber}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      File? savedFile;
      String locationMessage = '';

      try {
        if (Platform.isAndroid) {
          // For Android, try multiple accessible locations in order of preference
          try {
            // First try: Public Downloads folder (most accessible)
            String downloadsPath = '/storage/emulated/0/Download';
            Directory downloadsDirectory = Directory(downloadsPath);

            if (await downloadsDirectory.exists()) {
              savedFile = File('$downloadsPath/$fileName');
              await savedFile.writeAsBytes(await pdf.save());
              locationMessage = 'Downloaded to: Downloads/$fileName';
            } else {
              throw Exception('Downloads folder not accessible');
            }
          } catch (downloadsError) {
            // Second try: External storage Documents folder
            Directory? externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              // Try to access the public Documents folder first
              String publicPath = '/storage/emulated/0/Documents';
              Directory publicDocuments = Directory(publicPath);

              if (await publicDocuments.exists()) {
                savedFile = File('$publicPath/$fileName');
                await savedFile.writeAsBytes(await pdf.save());
                locationMessage = 'Downloaded to: Documents/$fileName';
              } else {
                // Fallback: Create Documents folder in app directory
                Directory documentsDir = Directory('${externalDir.path}/Documents');
                if (!await documentsDir.exists()) {
                  await documentsDir.create(recursive: true);
                }
                savedFile = File('${documentsDir.path}/$fileName');
                await savedFile.writeAsBytes(await pdf.save());
                locationMessage = 'Downloaded to: Phone Storage/Documents/$fileName';
              }
            }
          }
        } else {
          // For iOS, save to Documents directory (accessible via Files app)
          Directory documentsDirectory = await getApplicationDocumentsDirectory();
          savedFile = File('${documentsDirectory.path}/$fileName');
          await savedFile.writeAsBytes(await pdf.save());
          locationMessage = 'Downloaded to: Files App > On My iPhone > CrownLog > $fileName';
        }

        if (mounted && savedFile != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Receipt saved to Downloads!'),
                  Text(locationMessage, style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open Location',
                textColor: Colors.white,
                onPressed: () async {
                  // Show detailed location info
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.folder, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          const Text('File Location'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('File: $fileName'),
                          const SizedBox(height: 8),
                          Text(locationMessage),
                          const SizedBox(height: 16),
                          Text(
                            Platform.isAndroid
                              ? '📁 Open your file manager app (like Google Files or Samsung My Files) and look in Downloads or Documents folder. The file should be easily accessible.'
                              : '📁 Open the Files app on your iPhone, tap "On My iPhone" then look for the CrownLog folder. You can also access it from the Files widget.',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                        if (savedFile != null)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final ctx = context;
                              Navigator.of(ctx).pop();
                              try {
                                await Share.shareXFiles(
                                  [XFile(savedFile!.path)],
                                  text: 'CrownLog Hospital Bill for ${widget.patient.name}',
                                );
                              } catch (e) {
                                // Error during sharing - we can log this or handle it silently
                                debugPrint('Share error: $e');
                              }
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
      } catch (storageError) {
        // If Downloads access fails, save to app directory and inform user
        try {
          Directory appDir = await getApplicationDocumentsDirectory();
          savedFile = File('${appDir.path}/$fileName');
          await savedFile.writeAsBytes(await pdf.save());

          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ Bill saved to app storage'),
                    Text('Use Share button to save to Downloads', style: TextStyle(fontSize: 12)),
                  ],
                ),
                backgroundColor: Colors.orange.shade600,
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'Share',
                  textColor: Colors.white,
                  onPressed: () async {
                    try {
                      await Share.shareXFiles([XFile(savedFile!.path)]);
                    } catch (e) {
                      // Error during sharing - we can log this or handle it silently
                      debugPrint('Share error: $e');
                    }
                  },
                ),
              ),
            );
          }
        } catch (e) {
          throw Exception('Failed to save PDF: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatPdfCurrency(int amount) {
    // Format currency for PDF with Naira symbol using Unicode
    final formatter = NumberFormat('#,###');
    return '₦${formatter.format(amount)}';
  }
}
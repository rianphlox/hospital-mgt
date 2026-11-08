import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/register_patient_models.dart';
import '../../models/user_models.dart';
import '../../services/patient_register_service.dart';
import '../../widgets/add_patient_dialog.dart';
import 'register_patient_form_screen.dart';

/// Full register record for one patient, laid out like the NHMIS columns.
class RegisterPatientDetailScreen extends StatefulWidget {
  final UserProfile profile;
  final RegisterPatient patient;

  const RegisterPatientDetailScreen({
    super.key,
    required this.profile,
    required this.patient,
  });

  @override
  State<RegisterPatientDetailScreen> createState() =>
      _RegisterPatientDetailScreenState();
}

class _RegisterPatientDetailScreenState
    extends State<RegisterPatientDetailScreen> {
  late RegisterPatient _patient = widget.patient;

  bool get _canAdmit =>
      widget.profile.role == UserRole.nurse ||
      widget.profile.role == UserRole.admin;

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterPatientFormScreen(
          profile: widget.profile,
          existing: _patient,
        ),
      ),
    );
    if (saved == true) {
      final fresh = await PatientRegisterService.getPatient(_patient.id);
      if (fresh != null && mounted) setState(() => _patient = fresh);
    }
  }

  void _startAdmission() {
    showDialog(
      context: context,
      builder: (_) => AddPatientDialog(
        profile: widget.profile,
        initialName: _patient.name,
        registerPatientId: _patient.id,
        cardNumber: _patient.cardNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text('Card ${p.cardNumber} · ${p.registerYear}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1917),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit),
            onPressed: _edit,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE7E5E4)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 20,
                      color: Color(0xFF047857),
                    ),
                    const SizedBox(width: 8),
                    SelectableText(
                      p.cardNumber,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.sex.displayName} • ${p.ageDisplay}',
            style: const TextStyle(color: Color(0xFF78716C)),
          ),
          if (p.needsReview) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.reviewNotes.isEmpty
                          ? 'Some details need checking against the paper register.'
                          : p.reviewNotes,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_canAdmit) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startAdmission,
              icon: const Icon(Icons.local_hospital),
              label: const Text('Start admission'),
            ),
          ],
          _section('Patient', [
            _row('Card number', p.cardNumber),
            _row('Register year', '${p.registerYear}'),
            _row('Name', p.name),
            _row('Date of birth', p.dateOfBirth),
            _row('Sex', p.sex.displayName),
            _row(
              'Age',
              p.isAgeCalculated
                  ? '${p.ageDisplay} (from date of birth)'
                  : p.ageDisplay,
            ),
            _row('Contact address', p.contactAddress),
            _row('State of origin', p.stateOfOrigin),
            _row('Telephone', p.phone),
            _row('First contact with facility', p.firstContactDisplay),
          ]),
          _section('Next of kin', [
            _row('Name', p.nokName),
            _row('Relationship', p.nokRelationship),
            _row('Contact address', p.nokAddress),
            _row('Telephone', p.nokPhone),
          ]),
          _section('Register entry', [
            _row(
              'Visit date',
              p.visitDate != null ? dateFormat.format(p.visitDate!) : '',
            ),
            _row('LGA', p.lga),
            _row('Ward', p.ward),
            _row('Facility', p.facility),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFA8A29E),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E5E4)),
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF78716C)),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

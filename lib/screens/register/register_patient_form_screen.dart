import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/register_patient_models.dart';
import '../../models/user_models.dart';
import '../../services/patient_register_service.dart';
import '../../widgets/add_patient_dialog.dart' show TitleCaseTextInputFormatter;

/// Add / edit form that mirrors the columns of the NHMIS Daily General
/// Attendance Register. Pops `true` when saved.
class RegisterPatientFormScreen extends StatefulWidget {
  final UserProfile profile;
  final RegisterPatient? existing;

  const RegisterPatientFormScreen({super.key, required this.profile, this.existing});

  @override
  State<RegisterPatientFormScreen> createState() => _RegisterPatientFormScreenState();
}

class _RegisterPatientFormScreenState extends State<RegisterPatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  RegisterSex _sex = RegisterSex.unknown;
  AgeUnit _ageUnit = AgeUnit.years;
  AgeBand? _ageBand;
  bool _ageBandTouched = false;
  bool? _firstContact;
  DateTime? _visitDate;
  bool _needsReview = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    String v(String? s) => s ?? '';
    _c = {
      'cardNumber': TextEditingController(text: v(p?.cardNumber)),
      'name': TextEditingController(text: v(p?.name)),
      'dateOfBirth': TextEditingController(text: v(p?.dateOfBirth)),
      'age': TextEditingController(text: p?.age?.toString() ?? ''),
      'contactAddress': TextEditingController(text: v(p?.contactAddress)),
      'stateOfOrigin': TextEditingController(text: v(p?.stateOfOrigin)),
      'phone': TextEditingController(text: v(p?.phone)),
      'nokName': TextEditingController(text: v(p?.nokName)),
      'nokRelationship': TextEditingController(text: v(p?.nokRelationship)),
      'nokAddress': TextEditingController(text: v(p?.nokAddress)),
      'nokPhone': TextEditingController(text: v(p?.nokPhone)),
      'lga': TextEditingController(text: v(p?.lga)),
      'ward': TextEditingController(text: v(p?.ward)),
      'facility': TextEditingController(text: v(p?.facility)),
      'serialNo': TextEditingController(text: p?.serialNo?.toString() ?? ''),
      'reviewNotes': TextEditingController(text: v(p?.reviewNotes)),
    };
    if (p != null) {
      _sex = p.sex;
      _ageUnit = p.ageUnit;
      _ageBand = p.ageBand;
      _ageBandTouched = true;
      _firstContact = p.firstContact;
      _visitDate = p.visitDate;
      _needsReview = p.needsReview;
    } else {
      _visitDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateAutoBand() {
    if (_ageBandTouched) return;
    setState(() {
      _ageBand = AgeBandExtension.fromAge(int.tryParse(_c['age']!.text.trim()), _ageUnit);
    });
  }

  Future<void> _pickVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    String t(String key) => _c[key]!.text.trim();
    final patient = RegisterPatient(
      id: widget.existing?.id ?? '',
      cardNumber: t('cardNumber'),
      name: t('name'),
      dateOfBirth: t('dateOfBirth'),
      sex: _sex,
      age: int.tryParse(t('age')),
      ageUnit: _ageUnit,
      ageBand: _ageBand,
      contactAddress: t('contactAddress'),
      stateOfOrigin: t('stateOfOrigin'),
      phone: t('phone'),
      firstContact: _firstContact,
      nokName: t('nokName'),
      nokRelationship: t('nokRelationship'),
      nokAddress: t('nokAddress'),
      nokPhone: t('nokPhone'),
      visitDate: _visitDate,
      lga: t('lga'),
      ward: t('ward'),
      facility: t('facility'),
      serialNo: int.tryParse(t('serialNo')),
      needsReview: _needsReview,
      reviewNotes: t('reviewNotes'),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      createdBy: widget.existing?.createdBy ?? widget.profile.name,
    );
    try {
      if (_isEdit) {
        await PatientRegisterService.updatePatient(patient);
      } else {
        await PatientRegisterService.createPatient(patient);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? '${patient.name} updated' : '${patient.name} added to the register'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = e is StateError ? e.message : 'Could not save: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Register Entry' : 'Register Patient'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1917),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE7E5E4)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heading('Patient / client'),
            _field('name', '8. Name of patient / client',
                required: true, formatters: [TitleCaseTextInputFormatter()]),
            _field('cardNumber', '9. Card number', hint: 'e.g. B 50', required: true),
            _field('dateOfBirth', '10. Date of birth', hint: 'DD/MM/YY or DD/MM/YYYY'),
            _label('11 / 12. Sex'),
            SegmentedButton<RegisterSex>(
              segments: const [
                ButtonSegment(value: RegisterSex.male, label: Text('Male')),
                ButtonSegment(value: RegisterSex.female, label: Text('Female')),
                ButtonSegment(value: RegisterSex.unknown, label: Text('Not recorded')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field('age', 'Age', keyboard: TextInputType.number, onChanged: (_) => _updateAutoBand(),
                      validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    return int.tryParse(v!.trim()) == null ? 'Whole number' : null;
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<AgeUnit>(
                      initialValue: _ageUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const [
                        DropdownMenuItem(value: AgeUnit.days, child: Text('Days')),
                        DropdownMenuItem(value: AgeUnit.months, child: Text('Months')),
                        DropdownMenuItem(value: AgeUnit.years, child: Text('Years')),
                      ],
                      onChanged: (u) {
                        setState(() => _ageUnit = u ?? AgeUnit.years);
                        _updateAutoBand();
                      },
                    ),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<AgeBand?>(
              key: ValueKey(_ageBand),
              initialValue: _ageBand,
              decoration: const InputDecoration(labelText: 'Age band (as ticked on the register)'),
              items: [
                const DropdownMenuItem<AgeBand?>(value: null, child: Text('Not recorded')),
                for (final b in AgeBand.values)
                  DropdownMenuItem<AgeBand?>(value: b, child: Text(b.label)),
              ],
              onChanged: (b) => setState(() {
                _ageBand = b;
                _ageBandTouched = true;
              }),
            ),
            const SizedBox(height: 16),
            _field('contactAddress', '13. Contact address'),
            _field('stateOfOrigin', '14. State of origin'),
            _field('phone', '15. Telephone no.', keyboard: TextInputType.phone),
            _label('16. First contact with facility'),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Yes')),
                ButtonSegment(value: 0, label: Text('No')),
                ButtonSegment(value: -1, label: Text('Not recorded')),
              ],
              selected: {_firstContact == null ? -1 : (_firstContact! ? 1 : 0)},
              onSelectionChanged: (s) => setState(() {
                final v = s.first;
                _firstContact = v == -1 ? null : v == 1;
              }),
            ),
            _heading('17. Next of kin'),
            _field('nokName', '17a. Name', formatters: [TitleCaseTextInputFormatter()]),
            _field('nokRelationship', '17b. Relationship with client'),
            _field('nokAddress', '17c. Contact address'),
            _field('nokPhone', '17d. Telephone no.', keyboard: TextInputType.phone),
            _heading('Register entry'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Visit date'),
              subtitle: Text(_visitDate != null ? DateFormat('dd/MM/yyyy').format(_visitDate!) : 'Not set'),
              trailing: TextButton(onPressed: _pickVisitDate, child: const Text('Change')),
            ),
            _field('serialNo', 'S/N on register page', keyboard: TextInputType.number),
            _field('lga', 'LGA'),
            _field('ward', 'Ward'),
            _field('facility', 'Health facility'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Needs review'),
              subtitle: const Text('Flag details that must be checked against the paper register'),
              value: _needsReview,
              onChanged: (v) => setState(() => _needsReview = v),
            ),
            if (_needsReview) _field('reviewNotes', 'What needs checking', maxLines: 3),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save Changes' : 'Add to Register'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFFA8A29E),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Color(0xFF78716C))),
    );
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
    List<TitleCaseTextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _c[key],
        keyboardType: keyboard,
        maxLines: maxLines,
        inputFormatters: formatters,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: validator ??
            (required
                ? (v) => (v ?? '').trim().isEmpty ? 'Required' : null
                : null),
      ),
    );
  }
}

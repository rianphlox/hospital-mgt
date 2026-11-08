import 'package:flutter/material.dart';
import '../../models/register_patient_models.dart';
import '../../models/user_models.dart';
import '../../services/patient_register_service.dart';
import '../../utils/patient_register_utils.dart';
import '../../utils/register_age.dart';
import '../../utils/register_defaults.dart';
import '../../utils/register_import.dart' show parseRegisterDate;
import '../../widgets/add_patient_dialog.dart' show TitleCaseTextInputFormatter;

/// Add / edit form that mirrors the columns of the NHMIS Daily General
/// Attendance Register. Pops `true` when saved.
class RegisterPatientFormScreen extends StatefulWidget {
  final UserProfile profile;
  final RegisterPatient? existing;

  const RegisterPatientFormScreen({
    super.key,
    required this.profile,
    this.existing,
  });

  @override
  State<RegisterPatientFormScreen> createState() =>
      _RegisterPatientFormScreenState();
}

class _RegisterPatientFormScreenState extends State<RegisterPatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  RegisterSex _sex = RegisterSex.unknown;
  AgeUnit _ageUnit = AgeUnit.years;
  bool? _firstContact;
  DateTime? _visitDate;
  bool _dobEstimated = false;
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
      'registerYear': TextEditingController(
        text: '${p?.registerYear ?? DateTime.now().year}',
      ),
      'name': TextEditingController(text: v(p?.name)),
      'dateOfBirth': TextEditingController(
        text: formatDateOfBirth(v(p?.dateOfBirth), reference: p?.visitDate),
      ),
      'visitDate': TextEditingController(),
      'age': TextEditingController(text: p?.age?.toString() ?? ''),
      'contactAddress': TextEditingController(text: v(p?.contactAddress)),
      'stateOfOrigin': TextEditingController(text: v(p?.stateOfOrigin)),
      'phone': TextEditingController(text: v(p?.phone)),
      'nokName': TextEditingController(text: v(p?.nokName)),
      'nokRelationship': TextEditingController(text: v(p?.nokRelationship)),
      'nokAddress': TextEditingController(text: v(p?.nokAddress)),
      'nokPhone': TextEditingController(text: v(p?.nokPhone)),
      // Same for every entry at this hospital: prefilled, and shown on old
      // entries saved with them blank. Still editable.
      'lga': TextEditingController(
        text: RegisterDefaults.orDefault(p?.lga, RegisterDefaults.lga),
      ),
      'ward': TextEditingController(
        text: RegisterDefaults.orDefault(p?.ward, RegisterDefaults.ward),
      ),
      'facility': TextEditingController(
        text: RegisterDefaults.orDefault(
          p?.facility,
          RegisterDefaults.facility,
        ),
      ),
      'reviewNotes': TextEditingController(text: v(p?.reviewNotes)),
    };
    if (p != null) {
      _dobEstimated = p.dobEstimated;
      _sex = p.sex;
      _ageUnit = p.ageUnit;
      _firstContact = p.firstContact;
      _visitDate = p.visitDate;
      _needsReview = p.needsReview;
    } else {
      _visitDate = DateTime.now();
    }
    _c['visitDate']!.text = _visitDate == null
        ? ''
        : formatRegisterDate(_visitDate!);
  }

  DateTime get _ageReference => _visitDate ?? DateTime.now();

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (_visitDate != null &&
              _visitDate!.year >= 2000 &&
              !_visitDate!.isAfter(DateTime.now().add(const Duration(days: 1))))
          ? _visitDate!
          : DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
        _c['visitDate']!.text = formatRegisterDate(picked);
        // A new entry defaults to the selected registration date's year.
        // Editing a visit date must not silently change an existing card's year.
        if (!_isEdit) {
          _c['registerYear']!.text = '${picked.year}';
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    String t(String key) => _c[key]!.text.trim();
    // Age left empty: work it out from the date of birth now, on submit, so
    // it is stored with the record. A typed age is kept as entered.
    final age = resolveAgeOnSubmit(
      ageText: t('age'),
      unit: _ageUnit,
      dateOfBirth: t('dateOfBirth'),
      reference: _ageReference,
    );
    final dob = resolveDateOfBirthOnSubmit(
      dateOfBirth: t('dateOfBirth'),
      age: age,
      reference: _ageReference,
      alreadyEstimated: _dobEstimated,
    );
    final patient = RegisterPatient(
      id: widget.existing?.id ?? '',
      cardNumber: t('cardNumber'),
      registerYear: int.parse(t('registerYear')),
      name: t('name'),
      dateOfBirth: dob.value,
      dobEstimated: dob.estimated,
      sex: _sex,
      age: age?.value,
      ageUnit: age?.unit ?? _ageUnit,
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
          content: Text(
            _isEdit
                ? '${patient.name} updated'
                : '${patient.name} added to the register',
          ),
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
            _cardNumberField(),
            _field(
              'registerYear',
              'Register / card year *',
              keyboard: TextInputType.number,
              validator: (v) {
                final year = int.tryParse((v ?? '').trim());
                return year == null || year < 1900 || year > 9999
                    ? 'Enter a four-digit year (1900-9999)'
                    : null;
              },
            ),
            _heading('Patient / client'),
            _field(
              'name',
              '8. Name of patient / client',
              required: true,
              formatters: [TitleCaseTextInputFormatter()],
            ),
            _field(
              'dateOfBirth',
              '10. Date of birth',
              hint: 'DD/MM/YYYY',
              onChanged: (_) => setState(() => _dobEstimated = false),
              validator: (v) => validateDateOfBirth(
                v,
                _ageReference,
                referenceIsVisitDate: _visitDate != null,
              ),
            ),
            if (_dobEstimated)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Estimated DOB — replace with the real date when known.',
                ),
              ),
            _label('11 / 12. Sex'),
            SegmentedButton<RegisterSex>(
              segments: const [
                ButtonSegment(value: RegisterSex.male, label: Text('Male')),
                ButtonSegment(value: RegisterSex.female, label: Text('Female')),
                ButtonSegment(
                  value: RegisterSex.unknown,
                  label: Text('Not recorded'),
                ),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    'age',
                    'Age',
                    keyboard: TextInputType.number,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return null;
                      final age = int.tryParse(v!.trim());
                      return age == null || age < 0
                          ? 'Non-negative whole number'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<AgeUnit>(
                      initialValue: _ageUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const [
                        DropdownMenuItem(
                          value: AgeUnit.days,
                          child: Text('Days'),
                        ),
                        DropdownMenuItem(
                          value: AgeUnit.months,
                          child: Text('Months'),
                        ),
                        DropdownMenuItem(
                          value: AgeUnit.years,
                          child: Text('Years'),
                        ),
                      ],
                      onChanged: (u) =>
                          setState(() => _ageUnit = u ?? AgeUnit.years),
                    ),
                  ),
                ),
              ],
            ),
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
            _field(
              'nokName',
              '17a. Name',
              formatters: [TitleCaseTextInputFormatter()],
            ),
            _field('nokRelationship', '17b. Relationship with client'),
            _field('nokAddress', '17c. Contact address'),
            _field(
              'nokPhone',
              '17d. Telephone no.',
              keyboard: TextInputType.phone,
            ),
            _heading('Register entry'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: _c['visitDate'],
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: 'Entry / visit date',
                  hintText: 'DD/MM/YYYY',
                  suffixIcon: IconButton(
                    tooltip: 'Choose visit date',
                    icon: const Icon(Icons.event),
                    onPressed: _pickVisitDate,
                  ),
                ),
                validator: (value) =>
                    (value ?? '').trim().isNotEmpty &&
                        parseRegisterDate(value) == null
                    ? 'Enter a valid date (DD/MM/YYYY)'
                    : null,
                onChanged: (value) {
                  _visitDate = parseRegisterDate(value);
                  if (!_isEdit && _visitDate != null) {
                    _c['registerYear']!.text = '${_visitDate!.year}';
                  }
                },
              ),
            ),
            _field('lga', 'LGA'),
            _field('ward', 'Ward'),
            _field('facility', 'Health facility'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Needs review'),
              subtitle: const Text(
                'Flag details that must be checked against the paper register',
              ),
              value: _needsReview,
              onChanged: (v) => setState(() => _needsReview = v),
            ),
            if (_needsReview)
              _field('reviewNotes', 'What needs checking', maxLines: 3),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'Save Changes' : 'Add to Register'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Card number is the main identifier, so it sits first, on its own, in
  /// larger bold text, and is required and validated.
  Widget _cardNumberField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: TextFormField(
        controller: _c['cardNumber'],
        autofocus: !_isEdit,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.next,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        decoration: const InputDecoration(
          labelText: 'Card number *',
          hintText: 'e.g. B 50',
          helperText: 'A-L then a number. Unique within the card year.',
          prefixIcon: Icon(Icons.badge_outlined),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: validateCardNumber,
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
        validator:
            validator ??
            (required
                ? (v) => (v ?? '').trim().isEmpty ? 'Required' : null
                : null),
      ),
    );
  }
}

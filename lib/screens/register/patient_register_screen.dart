import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/register_patient_models.dart';
import '../../models/user_models.dart';
import '../../services/patient_register_service.dart';
import '../admin/import_patients_screen.dart';
import 'register_patient_detail_screen.dart';
import 'register_patient_form_screen.dart';

/// Patient Register: look up returning patients by card number or name.
/// Reachable from the Nurse and Admin dashboards.
class PatientRegisterScreen extends StatefulWidget {
  final UserProfile profile;

  const PatientRegisterScreen({super.key, required this.profile});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final _searchController = TextEditingController();

  /// Card number is the main way to find a patient, so it is the default.
  RegisterSearchMode _mode = RegisterSearchMode.cardNumber;
  int _currentYear = DateTime.now().year;
  late int? _selectedYear = _currentYear;
  late List<int> _years = [_currentYear];
  bool _reloadYears = true;
  List<RegisterPatient> _results = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounce;
  int _searchId = 0;

  bool get _isAdmin => widget.profile.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final currentYear = DateTime.now().year;
    if (currentYear != _currentYear) {
      if (_selectedYear == _currentYear) _selectedYear = currentYear;
      _currentYear = currentYear;
      _reloadYears = true;
    }
    final text = _searchController.text.trim();
    final id = ++_searchId;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final years = _reloadYears
          ? await PatientRegisterService.availableYears()
          : _years;
      final results = text.isEmpty
          ? await PatientRegisterService.recentPatients(year: _selectedYear)
          : await PatientRegisterService.search(
              text,
              _mode,
              year: _selectedYear,
            );
      if (!mounted || id != _searchId) return;
      setState(() {
        _years = {...years, if (_selectedYear != null) _selectedYear!}.toList()
          ..sort((a, b) => b.compareTo(a));
        _reloadYears = false;
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = [];
        _isLoading = false;
        _error = 'Search failed: $e';
      });
    }
  }

  void _setMode(RegisterSearchMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (_searchController.text.trim().isNotEmpty) _runSearch();
  }

  String get _hint {
    switch (_mode) {
      case RegisterSearchMode.cardNumber:
        return 'Card no, e.g. B 50';
      case RegisterSearchMode.name:
        return 'Name, e.g. Jane or Doe';
    }
  }

  Future<void> _openDetail(RegisterPatient patient) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterPatientDetailScreen(
          profile: widget.profile,
          patient: patient,
        ),
      ),
    );
    if (mounted) {
      _reloadYears = true;
      _runSearch();
    }
  }

  Future<void> _addPatient() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterPatientFormScreen(profile: widget.profile),
      ),
    );
    if (saved == true && mounted) {
      _reloadYears = true;
      _runSearch();
    }
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImportPatientsScreen(adminProfile: widget.profile),
      ),
    );
    if (mounted) {
      _reloadYears = true;
      _runSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Register'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1917),
        elevation: 0,
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Import patients',
              icon: const Icon(Icons.upload_file),
              onPressed: _openImport,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE7E5E4)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPatient,
        icon: const Icon(Icons.person_add),
        label: const Text('Register Patient'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey('register-year-$_selectedYear'),
              initialValue: _selectedYear ?? 0,
              decoration: const InputDecoration(
                labelText: 'Register year',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: [
                ..._years.map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text(
                      year == _currentYear ? '$year (current year)' : '$year',
                    ),
                  ),
                ),
                const DropdownMenuItem(value: 0, child: Text('All years')),
              ],
              onChanged: (year) {
                _debounce?.cancel();
                setState(() => _selectedYear = year == 0 ? null : year);
                _runSearch();
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<RegisterSearchMode>(
              segments: const [
                ButtonSegment(
                  value: RegisterSearchMode.cardNumber,
                  label: Text('Card No'),
                  icon: Icon(Icons.badge_outlined),
                ),
                ButtonSegment(
                  value: RegisterSearchMode.name,
                  label: Text('Name'),
                  icon: Icon(Icons.person_search),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _setMode(s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              textCapitalization: _mode == RegisterSearchMode.cardNumber
                  ? TextCapitalization.characters
                  : TextCapitalization.words,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _runSearch(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _runSearch();
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'Recently registered'
                  : '${_results.length} result${_results.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA8A29E),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildResults(query)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(String query) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 48,
              color: Color(0xFFA8A29E),
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'No patients for ${_selectedYear ?? 'all years'} yet'
                  : 'No patient found for "$query"',
              style: const TextStyle(color: Color(0xFF78716C)),
            ),
            if (_selectedYear != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Try a previous year or All years.',
                style: TextStyle(color: Color(0xFF78716C)),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _addPatient,
              icon: const Icon(Icons.person_add),
              label: const Text('Register a new patient'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => RegisterPatientTile(
        patient: _results[i],
        onTap: () => _openDetail(_results[i]),
      ),
    );
  }
}

/// Compact list row for a register patient.
class RegisterPatientTile extends StatelessWidget {
  final RegisterPatient patient;
  final VoidCallback? onTap;

  const RegisterPatientTile({super.key, required this.patient, this.onTap});

  @override
  Widget build(BuildContext context) {
    final details = [
      '${patient.registerYear}',
      patient.sex.displayName,
      patient.ageDisplay,
      if (patient.contactAddress.isNotEmpty) patient.contactAddress,
      if (patient.phone.isNotEmpty) patient.phone,
    ].join(' • ');
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE7E5E4)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            patient.cardNumber,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF047857),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                patient.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (patient.needsReview) ...[
              const SizedBox(width: 6),
              const Tooltip(
                message:
                    'Some details need checking against the paper register',
                child: Icon(Icons.flag, size: 16, color: Color(0xFFD97706)),
              ),
            ],
          ],
        ),
        subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

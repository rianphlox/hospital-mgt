import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/register_patient_models.dart';
import '../../models/user_models.dart';
import '../../services/patient_register_service.dart';
import '../../utils/register_import.dart';

/// Admin tool: load existing patients into the Patient Register from a CSV
/// or JSON file (same columns as the register export), preview, then save.
/// Rows whose card number already exists are skipped.
class ImportPatientsScreen extends StatefulWidget {
  final UserProfile adminProfile;

  const ImportPatientsScreen({super.key, required this.adminProfile});

  @override
  State<ImportPatientsScreen> createState() => _ImportPatientsScreenState();
}

class _ImportPatientsScreenState extends State<ImportPatientsScreen> {
  final _pasteController = TextEditingController();
  List<RegisterImportRow> _rows = [];
  String? _sourceName;
  String? _parseError;
  bool _checking = false;
  bool _importing = false;
  RegisterImportResult? _result;

  int get _validCount => _rows.where((r) => r.isValid && !r.isDuplicate).length;
  int get _duplicateCount => _rows.where((r) => r.isDuplicate).length;
  int get _invalidCount => _rows.where((r) => !r.isValid).length;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'json'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _parseError = 'Could not read ${file.name}');
      return;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    _pasteController.text = text;
    await _parse(text, file.name);
  }

  Future<void> _parse(String text, String sourceName) async {
    setState(() {
      _parseError = null;
      _result = null;
      _rows = [];
      _sourceName = sourceName;
    });
    if (text.trim().isEmpty) {
      setState(() => _parseError = 'Nothing to import');
      return;
    }
    List<RegisterImportRow> rows;
    try {
      rows = parseRegisterImport(text, createdBy: widget.adminProfile.name);
    } on FormatException catch (e) {
      setState(() => _parseError = e.message);
      return;
    }

    setState(() {
      _rows = rows;
      _checking = true;
    });
    try {
      final existing = await PatientRegisterService.existingCardNumbers(
        rows.where((r) => r.patient != null).map((r) => r.patient!),
      );
      markDuplicates(rows, existing);
    } catch (e) {
      // Still mark in-file duplicates if Firestore can't be reached.
      markDuplicates(rows, {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check existing card numbers: $e')),
        );
      }
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _import() async {
    final patients = _rows
        .where((r) => r.isValid && !r.isDuplicate)
        .map((r) => r.patient!)
        .toList();
    if (patients.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import patients'),
        content: Text(
          'Add ${patients.length} patient${patients.length == 1 ? '' : 's'} to the register?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      final result = await PatientRegisterService.importPatients(
        patients,
        createdBy: widget.adminProfile.name,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _importing = false;
        _rows = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Patients'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1917),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE7E5E4)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Upload a CSV or JSON file of register entries. The first CSV row must be the '
            'column names: cardNumber, registerYear, visitDate, name, dateOfBirth, sex, age, ageUnit, '
            'contactAddress, stateOfOrigin, phone, firstContact, nokName, nokRelationship, '
            'nokAddress, nokPhone, lga, ward, facility, needsReview, reviewNotes. '
            'Card number is the key field: rows without a valid card number are rejected, '
            'and cards already used in the same year are skipped. The registerYear (or year) column is optional: otherwise visitDate supplies the year, then the current year. Name is '
            'also required. Any other columns in the file are ignored.',
            style: TextStyle(color: Color(0xFF78716C)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importing ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose CSV / JSON file'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pasteController,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Or paste CSV / JSON here',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _importing
                  ? null
                  : () => _parse(_pasteController.text, 'pasted text'),
              icon: const Icon(Icons.preview),
              label: const Text('Preview'),
            ),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: 12),
            Text(_parseError!, style: const TextStyle(color: Colors.red)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _resultCard(_result!),
          ],
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'PREVIEW${_sourceName != null ? ' – $_sourceName' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA8A29E),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            if (_checking)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('$_validCount to import')),
                  Chip(label: Text('$_duplicateCount duplicate card no.')),
                  Chip(label: Text('$_invalidCount with errors')),
                ],
              ),
            const SizedBox(height: 8),
            ..._rows.map(_previewRow),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (_checking || _importing || _validCount == 0)
                  ? null
                  : _import,
              icon: _importing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                'Import $_validCount patient${_validCount == 1 ? '' : 's'}',
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _previewRow(RegisterImportRow row) {
    final p = row.patient;
    final Color color;
    final String status;
    if (!row.isValid) {
      color = Colors.red;
      status = row.errors.join('; ');
    } else if (row.isDuplicate) {
      color = const Color(0xFF78716C);
      status = 'Card number already registered in this year – will be skipped';
    } else {
      color = const Color(0xFF10B981);
      status = p!.needsReview
          ? 'Will import (flagged for review)'
          : 'Will import';
    }
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        dense: true,
        leading: Text(
          '#${row.rowNumber}',
          style: const TextStyle(color: Color(0xFF78716C)),
        ),
        title: Text(
          p == null
              ? 'Row ${row.rowNumber}'
              : '${p.cardNumber} · ${p.registerYear} – ${p.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          p == null
              ? status
              : '${p.sex.displayName} • ${p.ageDisplay} • ${p.phone.isEmpty ? 'no phone' : p.phone}\n$status',
        ),
        isThreeLine: p != null,
      ),
    );
  }

  Widget _resultCard(RegisterImportResult r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Imported ${r.imported} patient${r.imported == 1 ? '' : 's'}. '
        'Skipped ${r.skippedDuplicates} duplicate card number${r.skippedDuplicates == 1 ? '' : 's'}'
        '${r.skippedInvalid > 0 ? ' and ${r.skippedInvalid} invalid row${r.skippedInvalid == 1 ? '' : 's'}' : ''}.',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF047857),
        ),
      ),
    );
  }
}

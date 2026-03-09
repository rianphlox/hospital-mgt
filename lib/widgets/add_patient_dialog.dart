import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient_models.dart';
import '../models/user_models.dart';
import '../providers/data_provider.dart';

class AddPatientDialog extends StatefulWidget {
  final UserProfile profile;

  const AddPatientDialog({
    Key? key,
    required this.profile,
  }) : super(key: key);

  @override
  State<AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<AddPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();

  PatientType _selectedType = PatientType.inPatient;
  String _selectedWard = 'General Ward';

  final List<String> _wards = [
    'General Ward',
    'Maternity Ward',
    'Pediatric Ward',
    'Surgical Ward',
    'Emergency Ward',
  ];

  @override
  void initState() {
    super.initState();
    _selectedWard = widget.profile.ward ?? 'General Ward';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'New Patient',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Patient type selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F4), // Stone-100
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeTab(
                        'In-patient',
                        PatientType.inPatient,
                      ),
                    ),
                    Expanded(
                      child: _buildTypeTab(
                        'Out-patient',
                        PatientType.outPatient,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Patient name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Patient Full Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA8A29E),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. John Doe',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter patient name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Patient ID
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedType == PatientType.inPatient
                        ? 'Admission ID / Number'
                        : 'OPD ID / Number',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA8A29E),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _idController,
                    decoration: InputDecoration(
                      hintText: _selectedType == PatientType.inPatient
                          ? 'e.g. ADM-2024-001'
                          : 'e.g. OPD-2024-001',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter patient ID';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ward assignment (only for in-patients)
              if (_selectedType == PatientType.inPatient) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ward Assignment',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA8A29E),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedWard,
                      decoration: const InputDecoration(),
                      items: _wards.map((ward) {
                        return DropdownMenuItem(
                          value: ward,
                          child: Text(ward),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedWard = value!;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78716C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer<DataProvider>(
                      builder: (context, dataProvider, _) {
                        return ElevatedButton(
                          onPressed: dataProvider.isLoading
                              ? null
                              : _submitForm,
                          child: dataProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Admit Patient',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTab(String label, PatientType type) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF78716C),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final patient = Patient(
      id: '', // Will be generated by Firestore
      name: _nameController.text.trim(),
      admissionNumber: _idController.text.trim(),
      ward: _selectedType == PatientType.outPatient ? 'OPD' : _selectedWard,
      type: _selectedType,
      status: PatientStatus.active,
      createdAt: DateTime.now(),
    );

    try {
      await context.read<DataProvider>().createPatient(patient);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient ${patient.name} admitted successfully'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error admitting patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
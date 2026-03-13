import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient_models.dart';
import '../models/user_models.dart';
import '../providers/data_provider.dart';

class SimpleAddTreatmentDialog extends StatefulWidget {
  final Patient patient;
  final UserProfile profile;

  const SimpleAddTreatmentDialog({
    super.key,
    required this.patient,
    required this.profile,
  });

  @override
  State<SimpleAddTreatmentDialog> createState() => _SimpleAddTreatmentDialogState();
}

class _SimpleAddTreatmentDialogState extends State<SimpleAddTreatmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<TreatmentItem> _items = [TreatmentItem(name: '', quantity: 1)];

  // Common drugs/items for quick selection
  final List<String> _commonDrugs = [
    'Paracetamol',
    'Ibuprofen',
    'Amoxicillin',
    'Ceftriaxone',
    'Normal Saline',
    'IV Fluids',
    'Antibiotics',
    'Pain Relief',
    'Bandages',
    'Oxygen',
    'Blood Test',
    'X-Ray',
    'Injection',
    'Drip',
    'Dressing'
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_services,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Treatment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Patient: ${widget.patient.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Drugs/Items:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items list
                      Expanded(
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildSimpleItemRow(index),
                        ),
                      ),

                      // Add item button
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 16),
                        child: OutlinedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Another Item'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            foregroundColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer<DataProvider>(
                      builder: (context, dataProvider, _) {
                        return ElevatedButton(
                          onPressed: dataProvider.isLoading ? null : _saveTreatment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                          child: dataProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Treatment'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleItemRow(int index) {
    final item = _items[index];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header with remove button
          Row(
            children: [
              Text(
                'Item ${index + 1}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Drug/Item name input
          TextFormField(
            initialValue: item.name,
            decoration: const InputDecoration(
              labelText: 'Drug/Item Name',
              hintText: 'e.g., Paracetamol, IV Fluids, Bandages',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter drug/item name';
              }
              return null;
            },
            onChanged: (value) => _updateItem(index, name: value),
          ),
          const SizedBox(height: 12),

          // Quick selection buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonDrugs.map((drug) {
              return InkWell(
                onTap: () => _updateItem(index, name: drug),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.name == drug
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    drug,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.name == drug ? Colors.white : const Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Quantity input
          Row(
            children: [
              const Text(
                'Quantity:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  validator: (value) {
                    final qty = int.tryParse(value ?? '');
                    if (qty == null || qty <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final qty = int.tryParse(value) ?? 1;
                    _updateItem(index, quantity: qty);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Quick quantity buttons
              Row(
                children: [1, 2, 5].map((qty) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () => _updateItem(index, quantity: qty),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: item.quantity == qty
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          qty.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: item.quantity == qty ? Colors.white : const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addItem() {
    setState(() {
      _items.add(TreatmentItem(name: '', quantity: 1));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItem(int index, {String? name, int? quantity}) {
    setState(() {
      _items[index] = TreatmentItem(
        name: name ?? _items[index].name,
        quantity: quantity ?? _items[index].quantity,
      );
    });
  }

  Future<void> _saveTreatment() async {
    if (!_formKey.currentState!.validate()) return;

    // Filter out empty items
    final validItems = _items.where((item) => item.name.trim().isNotEmpty).toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final treatment = Treatment(
        id: '',
        patientId: widget.patient.id,
        nurseId: widget.profile.uid,
        nurseName: widget.profile.name,
        items: validItems,
        totalCharge: 0, // Will be set by admin during pricing
        timestamp: DateTime.now(),
        shift: NursingShiftExtension.getCurrentShift(),
        pricingStatus: TreatmentPricingStatus.pending,
      );

      await Provider.of<DataProvider>(context, listen: false)
          .addTreatment(widget.patient.id, treatment);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treatment logged successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient_models.dart';
import '../models/user_models.dart';
import '../providers/data_provider.dart';

class AddTreatmentDialog extends StatefulWidget {
  final Patient patient;
  final UserProfile profile;

  const AddTreatmentDialog({
    super.key,
    required this.patient,
    required this.profile,
  });

  @override
  State<AddTreatmentDialog> createState() => _AddTreatmentDialogState();
}

class _AddTreatmentDialogState extends State<AddTreatmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<TreatmentItem> _items = [
    TreatmentItem(name: '', quantity: 1)
  ];

  // Drug categories for organized dropdown
  final Map<String, List<QuickDrug>> _drugCategories = {
    'IV Fluids': QuickDrug.defaultDrugs.where((drug) =>
        drug.name.contains('Saline') ||
        drug.name.contains('Lactate') ||
        drug.name.contains('Glucose') ||
        drug.name.contains('Darrow')).toList(),
    'Antibiotics': QuickDrug.defaultDrugs.where((drug) =>
        drug.name.contains('Ceftriaxone') ||
        drug.name.contains('Metronidazole') ||
        drug.name.contains('Ciprofloxacin') ||
        drug.name.contains('Amoxicillin') ||
        drug.name.contains('Cefuroxime')).toList(),
    'Pain Relief': QuickDrug.defaultDrugs.where((drug) =>
        drug.name.contains('Paracetamol') ||
        drug.name.contains('Diclofenac') ||
        drug.name.contains('Tramadol') ||
        drug.name.contains('Ibuprofen') ||
        drug.name.contains('Morphine')).toList(),
    'Emergency': QuickDrug.defaultDrugs.where((drug) =>
        drug.name.contains('Adrenaline') ||
        drug.name.contains('Hydrocortisone') ||
        drug.name.contains('Atropine') ||
        drug.name.contains('Furosemide')).toList(),
    'Others': QuickDrug.defaultDrugs.where((drug) =>
        drug.name.contains('Vitamin') ||
        drug.name.contains('Oxygen') ||
        drug.name.contains('Blood') ||
        drug.name.contains('X-Ray')).toList(),
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF5F5F4)),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Log Treatment',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
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
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Items list
                      Expanded(
                        child: ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) => _buildItemRow(index),
                        ),
                      ),

                      // Add item button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: ElevatedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text(
                            'Add Another Item',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF5F5F4)),
                ),
              ),
              child: Column(
                children: [
                  // Pricing note
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF), // Blue-50
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0EA5E9)), // Blue-500
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF0EA5E9), // Blue-500
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pricing will be set by Doctor/Admin',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0369A1), // Blue-700
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Consumer<DataProvider>(
                          builder: (context, dataProvider, _) {
                            return ElevatedButton(
                              onPressed: dataProvider.isLoading ? null : _submitTreatment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                  : const Text(
                                      'Save Treatment',
                                      style: TextStyle(fontWeight: FontWeight.bold),
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
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with item number and remove button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Item ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (_items.length > 1)
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Drug/Item Name Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Item / Drug Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE7E5E4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    key: ValueKey('name_${index}_${item.name}'),
                    initialValue: item.name,
                    decoration: InputDecoration(
                      hintText: 'Type drug name or select from categories below',
                      hintStyle: const TextStyle(color: Color(0xFFA8A29E)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                      suffixIcon: item.name.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _updateItem(index, name: ''),
                            )
                          : null,
                    ),
                    onChanged: (value) => _updateItem(index, name: value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Selection Categories
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Selection',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 8),
                for (final category in _drugCategories.entries)
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                    childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
                    title: Text(
                      category.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: category.value.map((drug) {
                          final isSelected = item.name == drug.name;
                          return GestureDetector(
                            onTap: () => _selectQuickDrug(index, drug),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF5F5F4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFE7E5E4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    drug.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1C1917),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Quantity
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE7E5E4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _updateItem(
                          index,
                          quantity: (item.quantity > 1) ? item.quantity - 1 : 1,
                        ),
                        icon: const Icon(Icons.remove, size: 18),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('qty_${index}_${item.quantity}'),
                          initialValue: item.quantity.toString(),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _updateItem(
                            index,
                            quantity: int.tryParse(value) ?? 1,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _updateItem(
                          index,
                          quantity: item.quantity + 1,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addItem() {
    setState(() {
      _items.add(TreatmentItem(name: '', quantity: 1));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  void _updateItem(
    int index, {
    String? name,
    int? quantity,
  }) {
    setState(() {
      _items[index] = TreatmentItem(
        name: name ?? _items[index].name,
        quantity: quantity ?? _items[index].quantity,
      );
    });
  }

  void _selectQuickDrug(int index, QuickDrug drug) {
    _updateItem(index, name: drug.name);
  }

  Future<void> _submitTreatment() async {
    // Check for validation - only name and quantity needed for nurse logging
    if (_items.any((item) => item.name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all item names'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final total = 0; // No pricing at nurse level

    final treatment = Treatment(
      id: '', // Will be generated by Firestore
      patientId: widget.patient.id,
      nurseId: widget.profile.uid,
      nurseName: widget.profile.name,
      items: _items,
      totalCharge: total,
      timestamp: DateTime.now(), // Will be overridden by serverTimestamp in DataService
      pricingStatus: TreatmentPricingStatus.pending,
    );

    try {
      await context.read<DataProvider>().addTreatment(
            widget.patient.id,
            treatment,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treatment logged successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging treatment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
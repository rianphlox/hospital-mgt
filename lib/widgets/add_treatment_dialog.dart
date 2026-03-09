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
  List<TreatmentItem> _items = [
    TreatmentItem(name: '', quantity: 1, unitPrice: 0)
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
    final total = _items.fold(
      0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 700),
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
              child: Row(
                children: [
                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Charge',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA8A29E),
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '₦${total.toString()}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669), // Emerald-700
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Action buttons
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF78716C),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Consumer<DataProvider>(
                        builder: (context, dataProvider, _) {
                          return ElevatedButton(
                            onPressed: dataProvider.isLoading
                                ? null
                                : _submitTreatment,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
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
                                    'Save Log',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          );
                        },
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
                    initialValue: item.name,
                    decoration: InputDecoration(
                      hintText: 'Type drug name or select from categories below',
                      hintStyle: const TextStyle(color: Color(0xFFA8A29E)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                      suffixIcon: item.name.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _updateItem(index, name: '', unitPrice: 0),
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
                ..._drugCategories.entries.map((category) {
                  return ExpansionTile(
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
                                  Text(
                                    '₦${drug.price}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected
                                          ? Colors.white70
                                          : const Color(0xFF78716C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 16),

            // Quantity and Price Row
            Row(
              children: [
                // Quantity
                Expanded(
                  child: Column(
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
                ),
                const SizedBox(width: 16),

                // Unit Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unit Price (₦)',
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
                          initialValue: item.unitPrice.toString(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12),
                            prefixText: '₦ ',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _updateItem(
                            index,
                            unitPrice: int.tryParse(value) ?? 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Item Total
            if (item.name.isNotEmpty && item.unitPrice > 0)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Item Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      '₦${(item.quantity * item.unitPrice).toString()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                        fontSize: 16,
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

  void _addItem() {
    setState(() {
      _items.add(TreatmentItem(name: '', quantity: 1, unitPrice: 0));
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
    int? unitPrice,
  }) {
    setState(() {
      _items[index] = TreatmentItem(
        name: name ?? _items[index].name,
        quantity: quantity ?? _items[index].quantity,
        unitPrice: unitPrice ?? _items[index].unitPrice,
      );
    });
  }

  void _selectQuickDrug(int index, QuickDrug drug) {
    _updateItem(index, name: drug.name, unitPrice: drug.price);
  }

  Future<void> _submitTreatment() async {
    // Check for validation like React version
    if (_items.any((item) => item.name.isEmpty || item.unitPrice <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all item details with valid prices'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final total = _items.fold(
      0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );

    final treatment = Treatment(
      id: '', // Will be generated by Firestore
      patientId: widget.patient.id,
      nurseId: widget.profile.uid,
      nurseName: widget.profile.name,
      items: _items,
      totalCharge: total,
      timestamp: DateTime.now(), // Will be overridden by serverTimestamp in DataService
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
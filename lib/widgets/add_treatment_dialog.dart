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
  final _searchController = TextEditingController();
  final List<TreatmentItem> _items = [
    TreatmentItem(name: '', quantity: 1, dosage: '', instructions: '')
  ];
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Enhanced drug categories with search capability
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
    'All': QuickDrug.defaultDrugs,
  };

  List<QuickDrug> get filteredDrugs {
    final categoryDrugs = _drugCategories[_selectedCategory] ?? [];
    if (_searchQuery.isEmpty) return categoryDrugs;

    return categoryDrugs.where((drug) =>
      drug.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width > 800 ? 700 : MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 700,
        ),
        child: Column(
          children: [
            // Enhanced Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF5F5F4)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medical_services,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Log Treatment',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Patient: ${widget.patient.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAF9),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE7E5E4)),
                ),
              ),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for drugs, procedures, or treatments...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category Chips
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _drugCategories.keys.map((category) {
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xFF10B981),
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                        );
                      }).toList(),
                    ),
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

                      // Treatment Summary
                      if (_items.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.summarize, color: Color(0xFF059669), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Total: ${_items.length} treatment${_items.length > 1 ? 's' : ''} • ${_items.where((item) => item.name.isNotEmpty).length} ready',
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Add item button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add_box, size: 20),
                          label: Text(
                            _items.length >= 5 ? 'Add More' : 'Add Another Treatment',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
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
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header with item number and remove button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.medical_services,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Treatment ${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_items.length > 1)
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Drug/Item Name with Smart Suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medication, color: Color(0xFF059669), size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Drug / Treatment Name *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: item.name.isEmpty ? Colors.red.shade300 : const Color(0xFFE7E5E4),
                        width: item.name.isEmpty ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: TextFormField(
                      key: ValueKey('name_${index}_${item.name}'),
                      initialValue: item.name,
                      decoration: InputDecoration(
                        hintText: 'e.g., Paracetamol, IV Fluids, Blood Test...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                        suffixIcon: item.name.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _updateItem(index, name: ''),
                              )
                            : const Icon(Icons.search, color: Color(0xFF10B981)),
                      ),
                      onChanged: (value) => _updateItem(index, name: value),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Smart Quick Selection based on search
              if (filteredDrugs.isNotEmpty && _searchQuery.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Color(0xFF059669), size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Quick Suggestions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredDrugs.take(5).length,
                        itemBuilder: (context, drugIndex) {
                          final drug = filteredDrugs[drugIndex];
                          final isSelected = item.name == drug.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _selectQuickDrug(index, drug),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF10B981) : Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE7E5E4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    drug.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? Colors.white : const Color(0xFF1C1917),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Enhanced Quantity with Unit Selection
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.numbers, color: Color(0xFF059669), size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Quantity',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1917),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE7E5E4)),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
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
                                  backgroundColor: Colors.grey.shade100,
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
                                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  foregroundColor: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Dosage Field
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_hospital, color: Color(0xFF059669), size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Dosage',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1917),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE7E5E4)),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: TextFormField(
                            key: ValueKey('dosage_${index}'),
                            decoration: const InputDecoration(
                              hintText: 'e.g., 500mg, 2 tablets',
                              hintStyle: TextStyle(fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(12),
                            ),
                            onChanged: (value) => _updateItem(index, dosage: value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Administration Instructions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF059669), size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Administration Notes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE7E5E4)),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: TextFormField(
                      key: ValueKey('instructions_${index}'),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Take after meals, IV slowly, Apply to wound...',
                        hintStyle: TextStyle(fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                      onChanged: (value) => _updateItem(index, instructions: value),
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

  void _addItem() {
    setState(() {
      _items.add(TreatmentItem(name: '', quantity: 1, dosage: '', instructions: ''));
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
    String? dosage,
    String? instructions,
  }) {
    setState(() {
      _items[index] = TreatmentItem(
        name: name ?? _items[index].name,
        quantity: quantity ?? _items[index].quantity,
        dosage: dosage ?? _items[index].dosage,
        instructions: instructions ?? _items[index].instructions,
      );
    });
  }

  void _selectQuickDrug(int index, QuickDrug drug) {
    _updateItem(index, name: drug.name);
  }

  bool _validateForm() {
    // Check for empty names
    if (_items.any((item) => item.name.trim().isEmpty)) {
      _showErrorMessage('Please provide names for all treatments');
      return false;
    }

    // Check for duplicate names
    final names = _items.map((item) => item.name.trim().toLowerCase()).toList();
    final uniqueNames = names.toSet();
    if (names.length != uniqueNames.length) {
      _showErrorMessage('Please remove duplicate treatments');
      return false;
    }

    // Check for invalid quantities
    if (_items.any((item) => item.quantity < 1)) {
      _showErrorMessage('Quantity must be at least 1 for all treatments');
      return false;
    }

    return true;
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitTreatment() async {
    if (!_validateForm()) return;

    final total = 0; // No pricing at nurse level

    // Create treatment items with cleaned data
    final cleanedItems = _items.map((item) => TreatmentItem(
      name: item.name.trim(),
      quantity: item.quantity,
      dosage: item.dosage.trim(),
      instructions: item.instructions.trim(),
    )).toList();

    final treatment = Treatment(
      id: '', // Will be generated by Firestore
      patientId: widget.patient.id,
      nurseId: widget.profile.uid,
      nurseName: widget.profile.name,
      items: cleanedItems,
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
        _showSuccessMessage('${cleanedItems.length} treatment(s) logged successfully for ${widget.patient.name}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to log treatment: ${e.toString()}');
      }
    }
  }
}
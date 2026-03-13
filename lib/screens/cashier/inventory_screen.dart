import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../models/user_models.dart';
import '../../services/data_service.dart';
import 'package:intl/intl.dart';

class InventoryScreen extends StatefulWidget {
  final UserProfile profile;

  const InventoryScreen({
    super.key,
    required this.profile,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  InventoryCategory? _selectedCategory;
  StockStatus? _selectedStockStatus;
  bool _isLoading = true;
  List<InventoryItem> _inventoryItems = [];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  void _loadInventory() {
    DataService.getInventoryItems(
      category: _selectedCategory,
      stockStatus: _selectedStockStatus,
    ).listen((items) {
      setState(() {
        _inventoryItems = items;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1917),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE7E5E4),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showStockUpdateDialog,
            icon: const Icon(Icons.add_box),
            tooltip: 'Add Stock',
          ),
          IconButton(
            onPressed: _showLowStockAlert,
            icon: const Icon(Icons.warning_amber),
            tooltip: 'Low Stock Alert',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Inventory stats
                  _buildInventoryStats(),
                  const SizedBox(height: 24),

                  // Filters and search
                  _buildFiltersAndSearch(),
                  const SizedBox(height: 24),

                  // Inventory list
                  Expanded(
                    child: _buildInventoryList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInventoryStats() {
    final inStockCount = _inventoryItems.where((item) => item.stockStatus == StockStatus.inStock).length;
    final lowStockCount = _inventoryItems.where((item) => item.stockStatus == StockStatus.lowStock).length;
    final outOfStockCount = _inventoryItems.where((item) => item.stockStatus == StockStatus.outOfStock).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'IN STOCK',
            inStockCount.toString(),
            const Color(0xFF10B981),
            Icons.inventory,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'LOW STOCK',
            lowStockCount.toString(),
            const Color(0xFFEAB308),
            Icons.warning,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'OUT OF STOCK',
            outOfStockCount.toString(),
            const Color(0xFFEF4444),
            Icons.error_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E5E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Column(
      children: [
        // Search bar
        TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: 'Search inventory items...',
            prefixIcon: Icon(Icons.search, color: Color(0xFF78716C)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE7E5E4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE7E5E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Category filter
              DropdownButton<InventoryCategory?>(
                value: _selectedCategory,
                hint: const Text('All Categories'),
                items: [
                  const DropdownMenuItem<InventoryCategory?>(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...InventoryCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.displayName),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _isLoading = true;
                  });
                  _loadInventory();
                },
              ),
              const SizedBox(width: 16),

              // Stock status filter
              DropdownButton<StockStatus?>(
                value: _selectedStockStatus,
                hint: const Text('All Stock Levels'),
                items: [
                  const DropdownMenuItem<StockStatus?>(
                    value: null,
                    child: Text('All Stock Levels'),
                  ),
                  ...StockStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.displayName),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStockStatus = value;
                    _isLoading = true;
                  });
                  _loadInventory();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryList() {
    final filteredItems = _filterInventoryItems();

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      itemCount: filteredItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    final stockColor = _getStockStatusColor(item.stockStatus);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and stock status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.stockStatus.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: stockColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stock info
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Current Stock',
                    '${item.currentStock} ${item.unit}',
                    Icons.inventory_2,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Min Level',
                    '${item.minStockLevel} ${item.unit}',
                    Icons.warning_amber,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Unit Price',
                    '₦${item.unitPrice}',
                    Icons.attach_money,
                  ),
                ),
              ],
            ),

            // Category and expiry info
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.category.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                if (item.expiryDate != null) ...[
                  Icon(
                    item.isExpired ? Icons.error :
                    item.isExpiringSoon ? Icons.warning : Icons.check_circle,
                    size: 16,
                    color: item.isExpired ? Colors.red :
                           item.isExpiringSoon ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Exp: ${DateFormat('MMM d, yyyy').format(item.expiryDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isExpired ? Colors.red :
                             item.isExpiringSoon ? Colors.orange : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),

            // Action buttons
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showStockUpdateDialog(item),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add Stock',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showStockTransactions(item),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text(
                      'History',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1917),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.inventory_2,
              size: 40,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No inventory items found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStockStatusColor(StockStatus status) {
    switch (status) {
      case StockStatus.inStock:
        return const Color(0xFF10B981);
      case StockStatus.lowStock:
        return const Color(0xFFEAB308);
      case StockStatus.outOfStock:
        return const Color(0xFFEF4444);
    }
  }

  List<InventoryItem> _filterInventoryItems() {
    if (_searchQuery.isEmpty) return _inventoryItems;

    return _inventoryItems.where((item) {
      final query = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.category.displayName.toLowerCase().contains(query);
    }).toList();
  }

  void _showStockUpdateDialog([InventoryItem? item]) {
    showDialog(
      context: context,
      builder: (context) => _StockUpdateDialog(
        item: item,
        profile: widget.profile,
        onUpdated: () {
          _loadInventory();
        },
      ),
    );
  }

  void _showStockTransactions(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => _StockHistoryDialog(item: item),
    );
  }

  void _showLowStockAlert() {
    DataService.getLowStockItems().then((lowStockItems) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber, color: Color(0xFFEAB308)),
              const SizedBox(width: 8),
              const Text('Low Stock Alert'),
            ],
          ),
          content: lowStockItems.isEmpty
              ? const Text('All items are well stocked!')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${lowStockItems.length} items need attention:'),
                    const SizedBox(height: 16),
                    ...lowStockItems.take(5).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.name)),
                          Text(
                            '${item.currentStock} ${item.unit}',
                            style: TextStyle(
                              color: _getStockStatusColor(item.stockStatus),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (lowStockItems.length > 5)
                      Text('...and ${lowStockItems.length - 5} more'),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }
}

// Stock Update Dialog
class _StockUpdateDialog extends StatefulWidget {
  final InventoryItem? item;
  final UserProfile profile;
  final VoidCallback onUpdated;

  const _StockUpdateDialog({
    this.item,
    required this.profile,
    required this.onUpdated,
  });

  @override
  State<_StockUpdateDialog> createState() => _StockUpdateDialogState();
}

class _StockUpdateDialogState extends State<_StockUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  String _transactionType = 'restock';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _quantityController.text = widget.item!.currentStock.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item != null ? 'Update Stock: ${widget.item!.name}' : 'Update Stock'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.item != null) ...[
              Text('Current Stock: ${widget.item!.currentStock} ${widget.item!.unit}'),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              value: _transactionType,
              decoration: const InputDecoration(labelText: 'Transaction Type'),
              items: const [
                DropdownMenuItem(value: 'restock', child: Text('Restock')),
                DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                DropdownMenuItem(value: 'expired', child: Text('Remove Expired')),
              ],
              onChanged: (value) => setState(() => _transactionType = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                hintText: 'Enter new stock level',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter quantity';
                }
                if (int.tryParse(value) == null || int.parse(value) < 0) {
                  return 'Please enter valid quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter reason for stock change',
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter reason';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitUpdate,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate() || widget.item == null) return;

    setState(() => _isSubmitting = true);

    try {
      await DataService.updateStock(
        widget.item!.id,
        int.parse(_quantityController.text),
        widget.profile.uid,
        widget.profile.name,
        _reasonController.text,
        _transactionType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock updated successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}

// Stock History Dialog
class _StockHistoryDialog extends StatefulWidget {
  final InventoryItem item;

  const _StockHistoryDialog({required this.item});

  @override
  State<_StockHistoryDialog> createState() => _StockHistoryDialogState();
}

class _StockHistoryDialogState extends State<_StockHistoryDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock History: ${widget.item.name}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<StockTransaction>>(
                stream: DataService.getStockTransactions(itemId: widget.item.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No transaction history available'),
                    );
                  }

                  final transactions = snapshot.data!;
                  return ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final isPositive = transaction.quantityChange > 0;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPositive
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : const Color(0xFFEF4444).withValues(alpha: 0.1),
                          child: Icon(
                            isPositive ? Icons.add : Icons.remove,
                            color: isPositive
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        title: Text(
                          '${isPositive ? '+' : ''}${transaction.quantityChange}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPositive
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(transaction.reason),
                            Text(
                              '${transaction.userName} • ${DateFormat('MMM d, yyyy h:mm a').format(transaction.timestamp)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            transaction.type.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
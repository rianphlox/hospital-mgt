import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryCategory {
  ivFluids,
  antibiotics,
  painRelief,
  emergency,
  vitamins,
  equipment,
  supplies,
  other,
}

extension InventoryCategoryExtension on InventoryCategory {
  String get displayName {
    switch (this) {
      case InventoryCategory.ivFluids:
        return 'IV Fluids';
      case InventoryCategory.antibiotics:
        return 'Antibiotics';
      case InventoryCategory.painRelief:
        return 'Pain Relief';
      case InventoryCategory.emergency:
        return 'Emergency';
      case InventoryCategory.vitamins:
        return 'Vitamins';
      case InventoryCategory.equipment:
        return 'Equipment';
      case InventoryCategory.supplies:
        return 'Supplies';
      case InventoryCategory.other:
        return 'Other';
    }
  }

  static InventoryCategory fromString(String value) {
    switch (value) {
      case 'IV Fluids':
        return InventoryCategory.ivFluids;
      case 'Antibiotics':
        return InventoryCategory.antibiotics;
      case 'Pain Relief':
        return InventoryCategory.painRelief;
      case 'Emergency':
        return InventoryCategory.emergency;
      case 'Vitamins':
        return InventoryCategory.vitamins;
      case 'Equipment':
        return InventoryCategory.equipment;
      case 'Supplies':
        return InventoryCategory.supplies;
      case 'Other':
        return InventoryCategory.other;
      default:
        return InventoryCategory.other;
    }
  }
}

enum StockStatus {
  inStock,
  lowStock,
  outOfStock,
}

extension StockStatusExtension on StockStatus {
  String get displayName {
    switch (this) {
      case StockStatus.inStock:
        return 'In Stock';
      case StockStatus.lowStock:
        return 'Low Stock';
      case StockStatus.outOfStock:
        return 'Out of Stock';
    }
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String description;
  final InventoryCategory category;
  final int currentStock;
  final int minStockLevel; // Alert when stock falls below this
  final int unitPrice; // Price per unit
  final String unit; // e.g., "ml", "tablets", "units"
  final DateTime? expiryDate;
  final String? batchNumber;
  final String? supplier;
  final DateTime lastUpdated;
  final String updatedBy; // User ID who last updated

  InventoryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.currentStock,
    required this.minStockLevel,
    required this.unitPrice,
    required this.unit,
    this.expiryDate,
    this.batchNumber,
    this.supplier,
    required this.lastUpdated,
    required this.updatedBy,
  });

  // Calculate stock status based on current stock
  StockStatus get stockStatus {
    if (currentStock <= 0) {
      return StockStatus.outOfStock;
    } else if (currentStock <= minStockLevel) {
      return StockStatus.lowStock;
    } else {
      return StockStatus.inStock;
    }
  }

  // Check if item is expired or expiring soon (within 30 days)
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    return expiryDate!.isBefore(thirtyDaysFromNow);
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json, String id) {
    return InventoryItem(
      id: id,
      name: json['name'] as String,
      description: json['description'] as String,
      category: InventoryCategoryExtension.fromString(json['category'] as String),
      currentStock: json['currentStock'] as int,
      minStockLevel: json['minStockLevel'] as int,
      unitPrice: json['unitPrice'] as int,
      unit: json['unit'] as String,
      expiryDate: json['expiryDate'] != null
          ? (json['expiryDate'] as Timestamp).toDate()
          : null,
      batchNumber: json['batchNumber'] as String?,
      supplier: json['supplier'] as String?,
      lastUpdated: (json['lastUpdated'] as Timestamp).toDate(),
      updatedBy: json['updatedBy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category': category.displayName,
      'currentStock': currentStock,
      'minStockLevel': minStockLevel,
      'unitPrice': unitPrice,
      'unit': unit,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'batchNumber': batchNumber,
      'supplier': supplier,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'updatedBy': updatedBy,
    };
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    String? description,
    InventoryCategory? category,
    int? currentStock,
    int? minStockLevel,
    int? unitPrice,
    String? unit,
    DateTime? expiryDate,
    String? batchNumber,
    String? supplier,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      currentStock: currentStock ?? this.currentStock,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      supplier: supplier ?? this.supplier,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

class StockTransaction {
  final String id;
  final String itemId;
  final String itemName;
  final int quantityChange; // Positive for additions, negative for usage
  final String type; // 'restock', 'usage', 'adjustment', 'expired'
  final String reason;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final String? relatedTreatmentId; // If transaction is due to treatment usage

  StockTransaction({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantityChange,
    required this.type,
    required this.reason,
    required this.timestamp,
    required this.userId,
    required this.userName,
    this.relatedTreatmentId,
  });

  factory StockTransaction.fromJson(Map<String, dynamic> json, String id) {
    return StockTransaction(
      id: id,
      itemId: json['itemId'] as String,
      itemName: json['itemName'] as String,
      quantityChange: json['quantityChange'] as int,
      type: json['type'] as String,
      reason: json['reason'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      relatedTreatmentId: json['relatedTreatmentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantityChange': quantityChange,
      'type': type,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'userName': userName,
      'relatedTreatmentId': relatedTreatmentId,
    };
  }
}

// Default inventory items to populate the system
class DefaultInventoryItems {
  static const List<Map<String, dynamic>> items = [
    // IV Fluids
    {
      'name': 'Normal Saline',
      'description': '0.9% Sodium Chloride Solution - 500ml',
      'category': 'IV Fluids',
      'currentStock': 50,
      'minStockLevel': 10,
      'unitPrice': 1500,
      'unit': 'bag',
    },
    {
      'name': 'Ringer\'s Lactate',
      'description': 'Lactated Ringer\'s Solution - 500ml',
      'category': 'IV Fluids',
      'currentStock': 30,
      'minStockLevel': 8,
      'unitPrice': 1800,
      'unit': 'bag',
    },
    {
      'name': 'Glucose 5%',
      'description': '5% Dextrose in Water - 500ml',
      'category': 'IV Fluids',
      'currentStock': 25,
      'minStockLevel': 8,
      'unitPrice': 1500,
      'unit': 'bag',
    },

    // Antibiotics
    {
      'name': 'Ceftriaxone 1g',
      'description': 'Ceftriaxone Injection 1g',
      'category': 'Antibiotics',
      'currentStock': 100,
      'minStockLevel': 20,
      'unitPrice': 4500,
      'unit': 'vial',
    },
    {
      'name': 'Metronidazole',
      'description': 'Metronidazole 500mg Injection',
      'category': 'Antibiotics',
      'currentStock': 80,
      'minStockLevel': 15,
      'unitPrice': 1200,
      'unit': 'vial',
    },
    {
      'name': 'Ciprofloxacin',
      'description': 'Ciprofloxacin 500mg Tablets',
      'category': 'Antibiotics',
      'currentStock': 200,
      'minStockLevel': 50,
      'unitPrice': 2000,
      'unit': 'tablet',
    },

    // Pain Relief
    {
      'name': 'Paracetamol IV',
      'description': 'Paracetamol 1g/100ml Infusion',
      'category': 'Pain Relief',
      'currentStock': 40,
      'minStockLevel': 10,
      'unitPrice': 3000,
      'unit': 'vial',
    },
    {
      'name': 'Diclofenac 75mg',
      'description': 'Diclofenac Sodium 75mg Injection',
      'category': 'Pain Relief',
      'currentStock': 60,
      'minStockLevel': 15,
      'unitPrice': 1800,
      'unit': 'ampoule',
    },
    {
      'name': 'Tramadol 50mg',
      'description': 'Tramadol Hydrochloride 50mg Injection',
      'category': 'Pain Relief',
      'currentStock': 50,
      'minStockLevel': 10,
      'unitPrice': 2200,
      'unit': 'ampoule',
    },

    // Emergency
    {
      'name': 'Adrenaline 1mg',
      'description': 'Epinephrine 1mg/ml Injection',
      'category': 'Emergency',
      'currentStock': 20,
      'minStockLevel': 5,
      'unitPrice': 8000,
      'unit': 'ampoule',
    },
    {
      'name': 'Atropine',
      'description': 'Atropine Sulfate 1mg Injection',
      'category': 'Emergency',
      'currentStock': 25,
      'minStockLevel': 8,
      'unitPrice': 2500,
      'unit': 'ampoule',
    },

    // Equipment
    {
      'name': 'Disposable Syringes 5ml',
      'description': 'Sterile Disposable Syringes with Needle',
      'category': 'Supplies',
      'currentStock': 500,
      'minStockLevel': 100,
      'unitPrice': 150,
      'unit': 'piece',
    },
    {
      'name': 'IV Cannula 18G',
      'description': 'Intravenous Cannula 18 Gauge',
      'category': 'Supplies',
      'currentStock': 100,
      'minStockLevel': 25,
      'unitPrice': 800,
      'unit': 'piece',
    },
    {
      'name': 'Surgical Gloves (M)',
      'description': 'Sterile Latex Surgical Gloves Medium',
      'category': 'Supplies',
      'currentStock': 200,
      'minStockLevel': 50,
      'unitPrice': 120,
      'unit': 'pair',
    },
  ];
}
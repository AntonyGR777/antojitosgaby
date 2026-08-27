class SaleLine {
  const SaleLine({
    required this.dishName,
    required this.unitPrice,
    required this.quantity,
    this.stewName,
    this.tortillaType,
  });

  final String dishName;
  final double unitPrice;
  final int quantity;
  final String? stewName;
  final String? tortillaType;

  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
    'dishName': dishName,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'stewName': stewName,
    'tortillaType': tortillaType,
  };

  factory SaleLine.fromJson(Map<String, dynamic> json) => SaleLine(
    dishName: json['dishName'] as String,
    unitPrice: (json['unitPrice'] as num).toDouble(),
    quantity: json['quantity'] as int,
    stewName: json['stewName'] as String?,
    tortillaType: json['tortillaType'] as String?,
  );
}

class Sale {
  const Sale({required this.id, required this.createdAt, required this.lines});

  final String id;
  final DateTime createdAt;
  final List<SaleLine> lines;

  double get total => lines.fold(0, (sum, line) => sum + line.subtotal);
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'lines': lines.map((line) => line.toJson()).toList(),
  };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lines: (json['lines'] as List<dynamic>)
        .map((line) => SaleLine.fromJson(line as Map<String, dynamic>))
        .toList(),
  );
}

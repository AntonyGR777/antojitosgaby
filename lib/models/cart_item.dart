import 'dish.dart';

class CartItem {
  const CartItem({
    required this.dish,
    required this.quantity,
    this.stewName,
    this.tortillaType,
  });

  final Dish dish;
  final int quantity;
  final String? stewName;
  final String? tortillaType;

  double get subtotal => dish.price * quantity;
  String get cartKey => '${dish.id}::${stewName ?? ''}::${tortillaType ?? ''}';

  CartItem copyWith({Dish? dish, int? quantity}) => CartItem(
    dish: dish ?? this.dish,
    quantity: quantity ?? this.quantity,
    stewName: stewName,
    tortillaType: tortillaType,
  );
}

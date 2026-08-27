import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/dish.dart';
import '../models/sale.dart';
import '../models/sales_day.dart';
import '../services/local_storage.dart';

class PosProvider extends ChangeNotifier {
  PosProvider(this._storage);

  final LocalStorage _storage;
  final List<Dish> _menu = [];
  final Map<String, CartItem> _cart = {};
  final List<Sale> _sales = [];
  final List<String> _stews = [];

  List<Dish> get menu => List.unmodifiable(_menu);
  List<CartItem> get cart => List.unmodifiable(_cart.values);
  List<Sale> get sales => List.unmodifiable(_sales.reversed);
  List<String> get stews => List.unmodifiable(_stews);
  int get cartItemCount =>
      _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal =>
      _cart.values.fold(0, (sum, item) => sum + item.subtotal);
  List<Sale> get todaySales {
    final now = DateTime.now();
    return List.unmodifiable(
      _sales.where((sale) => _isSameDay(sale.createdAt, now)).toList().reversed,
    );
  }

  double get dailyTotal =>
      _totalWhere((date) => _isSameDay(date, DateTime.now()));

  double get weeklyTotal {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 7));
    return _totalWhere((date) => !date.isBefore(start) && date.isBefore(end));
  }

  double get monthlyTotal {
    final now = DateTime.now();
    return _totalWhere(
      (date) => date.year == now.year && date.month == now.month,
    );
  }

  double get yearlyTotal {
    final now = DateTime.now();
    return _totalWhere((date) => date.year == now.year);
  }

  double get allTimeTotal => _sales.fold(0, (sum, sale) => sum + sale.total);

  List<SalesDay> get salesHistory {
    final groups = <DateTime, List<Sale>>{};
    for (final sale in _sales) {
      final date = DateTime(
        sale.createdAt.year,
        sale.createdAt.month,
        sale.createdAt.day,
      );
      groups.putIfAbsent(date, () => []).add(sale);
    }
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return List.unmodifiable(
      dates.map(
        (date) => SalesDay(
          date: date,
          sales: List.unmodifiable(groups[date]!.reversed),
        ),
      ),
    );
  }

  Future<void> load() async {
    final hasSavedMenu = _storage.hasSavedMenu;
    final savedMenu = _storage.loadMenu();
    _menu
      ..clear()
      ..addAll(hasSavedMenu ? savedMenu : _initialMenu());
    _sales
      ..clear()
      ..addAll(_storage.loadSales());
    final hasSavedStews = _storage.hasSavedStews;
    final savedStews = _storage.loadStews();
    _stews
      ..clear()
      ..addAll(hasSavedStews ? savedStews : _initialStews);
    if (!hasSavedMenu) await _storage.saveMenu(_menu);
    if (!hasSavedStews) await _storage.saveStews(_stews);
    notifyListeners();
  }

  void addToCart(
    Dish dish, {
    String? stewName,
    String? tortillaType,
    int quantity = 1,
  }) {
    if (quantity <= 0) return;
    final key = '${dish.id}::${stewName ?? ''}::${tortillaType ?? ''}';
    final current = _cart[key];
    _cart[key] = CartItem(
      dish: dish,
      stewName: stewName,
      tortillaType: tortillaType,
      quantity: (current?.quantity ?? 0) + quantity,
    );
    notifyListeners();
  }

  void decreaseFromCart(String cartKey) {
    final current = _cart[cartKey];
    if (current == null) return;
    if (current.quantity == 1) {
      _cart.remove(cartKey);
    } else {
      _cart[cartKey] = current.copyWith(quantity: current.quantity - 1);
    }
    notifyListeners();
  }

  void removeFromCart(String cartKey) {
    _cart.remove(cartKey);
    notifyListeners();
  }

  Future<Sale?> chargeOrder() async {
    if (_cart.isEmpty) return null;
    final now = DateTime.now();
    final sale = Sale(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      lines: _cart.values
          .map(
            (item) => SaleLine(
              dishName: item.dish.name,
              unitPrice: item.dish.price,
              quantity: item.quantity,
              stewName: item.stewName,
              tortillaType: item.tortillaType,
            ),
          )
          .toList(),
    );
    _sales.add(sale);
    _cart.clear();
    notifyListeners();
    await _storage.saveSales(_sales);
    return sale;
  }

  Future<void> addDish(String name, double price) async {
    _menu.add(
      Dish(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        price: price,
      ),
    );
    notifyListeners();
    await _storage.saveMenu(_menu);
  }

  Future<void> updateDish(Dish updated) async {
    final index = _menu.indexWhere((dish) => dish.id == updated.id);
    if (index == -1) return;
    _menu[index] = updated;
    for (final entry in _cart.entries.toList()) {
      if (entry.value.dish.id == updated.id) {
        _cart[entry.key] = entry.value.copyWith(dish: updated);
      }
    }
    notifyListeners();
    await _storage.saveMenu(_menu);
  }

  Future<void> deleteDish(String dishId) async {
    _menu.removeWhere((dish) => dish.id == dishId);
    _cart.removeWhere((_, item) => item.dish.id == dishId);
    notifyListeners();
    await _storage.saveMenu(_menu);
  }

  Future<void> closeDay() async {
    // Las ventas ya se guardan al cobrar. Este guardado explícito permite
    // cerrar el corte sin destruir el historial.
    await _storage.saveSales(_sales);
  }

  double _totalWhere(bool Function(DateTime date) includes) => _sales
      .where((sale) => includes(sale.createdAt))
      .fold(0, (sum, sale) => sum + sale.total);

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  Future<void> addStew(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty ||
        _stews.any((stew) => stew.toLowerCase() == normalized.toLowerCase())) {
      return;
    }
    _stews.add(normalized);
    notifyListeners();
    await _storage.saveStews(_stews);
  }

  Future<void> updateStew(int index, String name) async {
    final normalized = name.trim();
    if (index < 0 || index >= _stews.length || normalized.isEmpty) return;
    _stews[index] = normalized;
    notifyListeners();
    await _storage.saveStews(_stews);
  }

  Future<void> deleteStew(int index) async {
    if (index < 0 || index >= _stews.length) return;
    _stews.removeAt(index);
    notifyListeners();
    await _storage.saveStews(_stews);
  }

  List<Dish> _initialMenu() => const [
    Dish(id: 'tacos', name: 'Tacos', price: 18),
    Dish(id: 'sopes', name: 'Sopes', price: 28),
    Dish(id: 'gorditas', name: 'Gorditas', price: 30),
    Dish(id: 'quesadillas', name: 'Quesadillas', price: 35),
    Dish(id: 'tostadas', name: 'Tostadas', price: 32),
    Dish(id: 'refresco', name: 'Refresco', price: 25),
  ];

  static const _initialStews = [
    'Picadillo',
    'Deshebrada',
    'Chicharrón',
    'Papa con chorizo',
    'Frijoles',
  ];
}

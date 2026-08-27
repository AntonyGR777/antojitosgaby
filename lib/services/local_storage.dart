import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dish.dart';
import '../models/sale.dart';

class LocalStorage {
  LocalStorage(this._preferences);

  static const _menuKey = 'pos_menu_v1';
  static const _salesKey = 'pos_sales_v1';
  static const _stewsKey = 'pos_stews_v1';
  final SharedPreferences _preferences;

  bool get hasSavedMenu => _preferences.containsKey(_menuKey);
  bool get hasSavedStews => _preferences.containsKey(_stewsKey);

  List<Dish> loadMenu() {
    final source = _preferences.getString(_menuKey);
    if (source == null) return [];
    try {
      return (jsonDecode(source) as List<dynamic>)
          .map((item) => Dish.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  List<Sale> loadSales() {
    final source = _preferences.getString(_salesKey);
    if (source == null) return [];
    try {
      return (jsonDecode(source) as List<dynamic>)
          .map((item) => Sale.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  List<String> loadStews() => _preferences.getStringList(_stewsKey) ?? [];

  Future<void> saveMenu(List<Dish> menu) => _preferences.setString(
    _menuKey,
    jsonEncode(menu.map((dish) => dish.toJson()).toList()),
  );

  Future<void> saveSales(List<Sale> sales) => _preferences.setString(
    _salesKey,
    jsonEncode(sales.map((sale) => sale.toJson()).toList()),
  );

  Future<void> saveStews(List<String> stews) =>
      _preferences.setStringList(_stewsKey, stews);
}

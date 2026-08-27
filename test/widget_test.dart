import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/dish.dart';
import 'package:flutter_application_1/providers/pos_provider.dart';
import 'package:flutter_application_1/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PosProvider> createProvider() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final provider = PosProvider(LocalStorage(preferences));
    await provider.load();
    return provider;
  }

  testWidgets('agrega cantidades de varios guisos y cobra el pedido', (
    tester,
  ) async {
    final provider = await createProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const PosApp()),
    );

    expect(find.text('Nuevo pedido'), findsOneWidget);
    expect(find.text('Ticket actual'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dish_tacos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harina'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stew_plus_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stew_plus_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stew_plus_1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add_stew_selection_button')));
    await tester.pumpAndSettle();

    expect(provider.cartItemCount, 3);
    expect(provider.cart, hasLength(2));
    expect(provider.cartTotal, 54);
    expect(provider.cart.first.stewName, 'Picadillo');
    expect(provider.cart.last.stewName, 'Deshebrada');
    expect(
      provider.cart.every((item) => item.tortillaType == 'Harina'),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('charge_button')));
    await tester.pumpAndSettle();
    expect(provider.cartItemCount, 0);
    expect(provider.sales, hasLength(1));
    expect(provider.dailyTotal, 54);
    expect(provider.sales.single.lines, hasLength(2));
    expect(
      provider.sales.single.lines.every(
        (line) => line.tortillaType == 'Harina',
      ),
      isTrue,
    );
    expect(find.text('Venta cobrada: \$54.00'), findsOneWidget);
  });

  testWidgets('crea un platillo desde el formulario en pantalla móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = await createProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const PosApp()),
    );

    await tester.tap(find.text('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_dish_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('dish_name_field')),
      'Pambazo',
    );
    await tester.enterText(
      find.byKey(const ValueKey('dish_price_field')),
      '48.50',
    );
    await tester.tap(find.byKey(const ValueKey('save_dish_button')));
    await tester.pumpAndSettle();

    expect(provider.menu.any((dish) => dish.name == 'Pambazo'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra resúmenes e historial en pantalla móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = await createProvider();
    provider.addToCart(
      provider.menu.firstWhere((dish) => dish.id == 'refresco'),
    );
    await provider.chargeOrder();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: provider, child: const PosApp()),
    );

    await tester.tap(find.text('Corte'));
    await tester.pumpAndSettle();

    expect(find.text('ESTA SEMANA'), findsOneWidget);
    expect(find.text('ESTE MES'), findsOneWidget);
    expect(find.text('ESTE AÑO'), findsOneWidget);
    expect(find.text('Historial por día'), findsOneWidget);
  });

  test('persiste el menú y las ventas en SharedPreferences', () async {
    final provider = await createProvider();
    await provider.addDish('Huarache', 55);
    provider.addToCart(provider.menu.last);
    await provider.chargeOrder();
    await provider.closeDay();

    expect(provider.sales, hasLength(1));

    final preferences = await SharedPreferences.getInstance();
    final restored = PosProvider(LocalStorage(preferences));
    await restored.load();

    expect(restored.menu.any((dish) => dish.name == 'Huarache'), isTrue);
    expect(restored.stews, contains('Picadillo'));
    expect(restored.sales, hasLength(1));
    expect(restored.dailyTotal, 55);
  });

  test('agrupa el historial por día y calcula todos los periodos', () async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    Map<String, dynamic> sale(String id, DateTime date, double price) => {
      'id': id,
      'createdAt': date.toIso8601String(),
      'lines': [
        {
          'dishName': 'Producto',
          'unitPrice': price,
          'quantity': 1,
          'stewName': null,
          'tortillaType': null,
        },
      ],
    };
    SharedPreferences.setMockInitialValues({
      'pos_sales_v1': jsonEncode([
        sale('ayer', yesterday, 20),
        sale('hoy', now, 10),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final provider = PosProvider(LocalStorage(preferences));
    await provider.load();

    expect(provider.salesHistory, hasLength(2));
    expect(provider.dailyTotal, 10);
    expect(provider.weeklyTotal, greaterThanOrEqualTo(10));
    expect(provider.monthlyTotal, greaterThanOrEqualTo(10));
    expect(provider.yearlyTotal, greaterThanOrEqualTo(10));
    expect(provider.allTimeTotal, 30);
  });

  test('solo tacos y gorditas solicitan guiso', () {
    final taco = Dish.fromJson({'id': '1', 'name': 'Tacos', 'price': 18});
    final gordita = Dish.fromJson({'id': '2', 'name': 'Gorditas', 'price': 30});
    final sope = Dish.fromJson({'id': '3', 'name': 'Sopes', 'price': 28});
    final drink = Dish.fromJson({'id': '4', 'name': 'Refresco', 'price': 25});
    final tacoDeChile = Dish.fromJson({
      'id': '5',
      'name': 'Tacos de chile',
      'price': 22,
    });

    expect(taco.asksForStew, isTrue);
    expect(taco.asksForTortilla, isTrue);
    expect(gordita.asksForStew, isTrue);
    expect(gordita.asksForTortilla, isFalse);
    expect(sope.asksForStew, isFalse);
    expect(drink.asksForStew, isFalse);
    expect(tacoDeChile.asksForStew, isFalse);
    expect(tacoDeChile.asksForTortilla, isFalse);
  });
}

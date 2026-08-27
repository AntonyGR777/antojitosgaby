import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../providers/pos_provider.dart';
import '../utils/formatters.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final menu = _DishGrid(wide: wide);
        const ticket = _TicketPanel();
        if (wide) {
          return Row(
            children: [
              Expanded(flex: 3, child: menu),
              const VerticalDivider(width: 1),
              const SizedBox(width: 360, child: ticket),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 5, child: menu),
            const Divider(height: 1),
            const Expanded(flex: 4, child: ticket),
          ],
        );
      },
    );
  }
}

class _DishGrid extends StatelessWidget {
  const _DishGrid({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final menu = context.select<PosProvider, List<Dish>>((pos) => pos.menu);
    if (menu.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Agrega platillos desde la sección Menú.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: wide ? 240 : 190,
        mainAxisExtent: wide ? 125 : 112,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: menu.length,
      itemBuilder: (context, index) {
        final dish = menu[index];
        return FilledButton.tonal(
          key: ValueKey('dish_${dish.id}'),
          style: FilledButton.styleFrom(
            padding: EdgeInsets.all(wide ? 12 : 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: () => _captureDish(context, dish),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dish.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                money(dish.price),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureDish(BuildContext context, Dish dish) async {
    final pos = context.read<PosProvider>();
    if (!dish.asksForStew) {
      pos.addToCart(dish);
      return;
    }
    if (pos.stews.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un guiso desde Menú.')),
      );
      return;
    }

    final selection = await showModalBottomSheet<_StewSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _StewSelectorSheet(
        dish: dish,
        stews: pos.stews,
        chooseTortilla: dish.asksForTortilla,
      ),
    );
    if (selection == null || !context.mounted) return;
    for (final entry in selection.quantities.entries) {
      pos.addToCart(
        dish,
        stewName: entry.key,
        tortillaType: selection.tortillaType,
        quantity: entry.value,
      );
    }
  }
}

class _StewSelectorSheet extends StatefulWidget {
  const _StewSelectorSheet({
    required this.dish,
    required this.stews,
    required this.chooseTortilla,
  });

  final Dish dish;
  final List<String> stews;
  final bool chooseTortilla;

  @override
  State<_StewSelectorSheet> createState() => _StewSelectorSheetState();
}

class _StewSelectorSheetState extends State<_StewSelectorSheet> {
  late final List<int> _quantities = List.filled(widget.stews.length, 0);
  String _tortillaType = 'Maíz';

  int get _total => _quantities.fold(0, (sum, quantity) => sum + quantity);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿De qué guiso serán los ${widget.dish.name}?',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Indica cuántos quieres de cada guiso',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (widget.chooseTortilla) ...[
              Text(
                'Tipo de tortilla',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const ValueKey('tortilla_selector'),
                segments: const [
                  ButtonSegment(
                    value: 'Maíz',
                    label: Text('Maíz'),
                    icon: Icon(Icons.circle_outlined),
                  ),
                  ButtonSegment(
                    value: 'Harina',
                    label: Text('Harina'),
                    icon: Icon(Icons.circle),
                  ),
                ],
                selected: {_tortillaType},
                onSelectionChanged: (selection) =>
                    setState(() => _tortillaType = selection.first),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ListView.separated(
                itemCount: widget.stews.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final quantity = _quantities[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 68,
                    title: Text(
                      widget.stews[index],
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          key: ValueKey('stew_minus_$index'),
                          onPressed: quantity == 0
                              ? null
                              : () => setState(() => _quantities[index]--),
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '$quantity',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          key: ValueKey('stew_plus_$index'),
                          onPressed: () => setState(() => _quantities[index]++),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                key: const ValueKey('add_stew_selection_button'),
                onPressed: _total == 0
                    ? null
                    : () {
                        final result = <String, int>{};
                        for (
                          var index = 0;
                          index < widget.stews.length;
                          index++
                        ) {
                          if (_quantities[index] > 0) {
                            result[widget.stews[index]] = _quantities[index];
                          }
                        }
                        Navigator.pop(
                          context,
                          _StewSelection(
                            quantities: result,
                            tortillaType: widget.chooseTortilla
                                ? _tortillaType
                                : null,
                          ),
                        );
                      },
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  'AGREGAR $_total AL TICKET',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StewSelection {
  const _StewSelection({required this.quantities, this.tortillaType});

  final Map<String, int> quantities;
  final String? tortillaType;
}

class _TicketPanel extends StatelessWidget {
  const _TicketPanel();

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ticket actual',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${pos.cartItemCount} productos'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: pos.cart.isEmpty
                  ? const Center(child: Text('Toca un platillo para agregarlo'))
                  : ListView.separated(
                      itemCount: pos.cart.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = pos.cart[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.dish.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.stewName != null)
                                Text(
                                  [
                                    item.stewName!,
                                    if (item.tortillaType != null)
                                      'Tortilla de ${item.tortillaType!.toLowerCase()}',
                                  ].join(' · '),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Quitar uno',
                                    onPressed: () =>
                                        pos.decreaseFromCart(item.cartKey),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Agregar uno',
                                    onPressed: () => pos.addToCart(
                                      item.dish,
                                      stewName: item.stewName,
                                      tortillaType: item.tortillaType,
                                    ),
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                money(item.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar del ticket',
                                onPressed: () =>
                                    pos.removeFromCart(item.cartKey),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  money(pos.cartTotal),
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                key: const ValueKey('charge_button'),
                onPressed: pos.cart.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final sale = await pos.chargeOrder();
                        if (sale != null) {
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Venta cobrada: ${money(sale.total)}',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                        }
                      },
                icon: const Icon(Icons.payments, size: 27),
                label: const Text(
                  'COBRAR / GUARDAR',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

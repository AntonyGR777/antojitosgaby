import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../providers/pos_provider.dart';
import '../utils/formatters.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<PosProvider>().menu;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    key: const ValueKey('add_dish_button'),
                    onPressed: () => _showDishForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'NUEVO PLATILLO',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    key: const ValueKey('manage_stews_button'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _StewManagerDialog(),
                    ),
                    icon: const Icon(Icons.soup_kitchen_outlined),
                    label: const Text(
                      'GUISOS',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: menu.isEmpty
              ? const Center(
                  child: Text('Todavía no hay platillos en el menú.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: menu.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final dish = menu[index];
                    return Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: ListTile(
                        minTileHeight: 72,
                        leading: CircleAvatar(
                          child: Text(
                            dish.name.isEmpty
                                ? '?'
                                : dish.name[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          dish.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${money(dish.price)} · '
                          '${dish.asksForTortilla
                              ? 'Guiso · Maíz o harina'
                              : dish.asksForStew
                              ? 'Solicita guiso'
                              : 'Captura directa'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Editar',
                              onPressed: () =>
                                  _showDishForm(context, dish: dish),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            const SizedBox(width: 6),
                            IconButton.filledTonal(
                              tooltip: 'Eliminar',
                              onPressed: () => _confirmDelete(context, dish),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showDishForm(BuildContext context, {Dish? dish}) async {
    final result = await showDialog<_DishFormResult>(
      context: context,
      builder: (_) => _DishFormDialog(dish: dish),
    );

    if (result == null || !context.mounted) return;
    final pos = context.read<PosProvider>();
    if (dish == null) {
      await pos.addDish(result.name, result.price);
    } else {
      await pos.updateDish(
        dish.copyWith(name: result.name, price: result.price),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Dish dish) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar platillo'),
        content: Text('¿Eliminar “${dish.name}” del menú?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && context.mounted) {
      await context.read<PosProvider>().deleteDish(dish.id);
    }
  }
}

class _DishFormDialog extends StatefulWidget {
  const _DishFormDialog({this.dish});

  final Dish? dish;

  @override
  State<_DishFormDialog> createState() => _DishFormDialogState();
}

class _DishFormDialogState extends State<_DishFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dish?.name ?? '');
    _priceController = TextEditingController(
      text: widget.dish?.price.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _DishFormResult(
        _nameController.text.trim(),
        double.parse(_priceController.text.replaceAll(',', '.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.dish == null ? 'Nuevo platillo' : 'Editar platillo'),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('dish_name_field'),
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del platillo',
                  prefixIcon: Icon(Icons.restaurant),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe un nombre'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('dish_price_field'),
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  final price = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );
                  return price == null || price <= 0
                      ? 'Ingresa un precio válido'
                      : null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('save_dish_button'),
          onPressed: _submit,
          child: Text(widget.dish == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}

class _DishFormResult {
  const _DishFormResult(this.name, this.price);

  final String name;
  final double price;
}

class _StewManagerDialog extends StatelessWidget {
  const _StewManagerDialog();

  @override
  Widget build(BuildContext context) {
    final stews = context.watch<PosProvider>().stews;
    return AlertDialog(
      title: const Text('Guisos disponibles'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: stews.isEmpty
            ? const Center(child: Text('Agrega el primer guiso.'))
            : ListView.builder(
                itemCount: stews.length,
                itemBuilder: (context, index) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(stews[index]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar guiso',
                        onPressed: () =>
                            _renameStew(context, index, stews[index]),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Eliminar guiso',
                        onPressed: () =>
                            context.read<PosProvider>().deleteStew(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          key: const ValueKey('add_stew_button'),
          onPressed: () => _addStew(context),
          icon: const Icon(Icons.add),
          label: const Text('Agregar guiso'),
        ),
      ],
    );
  }

  Future<void> _addStew(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _StewNameDialog(title: 'Nuevo guiso'),
    );
    if (name != null && context.mounted) {
      await context.read<PosProvider>().addStew(name);
    }
  }

  Future<void> _renameStew(
    BuildContext context,
    int index,
    String currentName,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _StewNameDialog(title: 'Editar guiso', initialValue: currentName),
    );
    if (name != null && context.mounted) {
      await context.read<PosProvider>().updateStew(index, name);
    }
  }
}

class _StewNameDialog extends StatefulWidget {
  const _StewNameDialog({required this.title, this.initialValue = ''});

  final String title;
  final String initialValue;

  @override
  State<_StewNameDialog> createState() => _StewNameDialogState();
}

class _StewNameDialogState extends State<_StewNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('stew_name_field'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nombre del guiso'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

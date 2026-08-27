import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sale.dart';
import '../providers/pos_provider.dart';
import '../utils/formatters.dart';

class DailySummaryScreen extends StatelessWidget {
  const DailySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              Text(
                'Resumen de ventas',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 5 : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: columns == 5 ? 1.65 : 1.8,
                    children: [
                      _SummaryCard(
                        label: 'HOY',
                        value: pos.dailyTotal,
                        icon: Icons.today,
                        emphasized: true,
                        valueKey: const ValueKey('daily_total'),
                      ),
                      _SummaryCard(
                        label: 'ESTA SEMANA',
                        value: pos.weeklyTotal,
                        icon: Icons.date_range,
                      ),
                      _SummaryCard(
                        label: 'ESTE MES',
                        value: pos.monthlyTotal,
                        icon: Icons.calendar_month,
                      ),
                      _SummaryCard(
                        label: 'ESTE AÑO',
                        value: pos.yearlyTotal,
                        icon: Icons.event_note,
                      ),
                      _SummaryCard(
                        label: 'HISTÓRICO',
                        value: pos.allTimeTotal,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Historial por día',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${pos.salesHistory.length} días'),
                ],
              ),
              const SizedBox(height: 10),
              if (pos.salesHistory.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('Aún no hay ventas registradas.')),
                )
              else
                ...pos.salesHistory.map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: ExpansionTile(
                        initiallyExpanded:
                            day.date.year == DateTime.now().year &&
                            day.date.month == DateTime.now().month &&
                            day.date.day == DateTime.now().day,
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt_long_outlined),
                        ),
                        title: Text(
                          shortDate(day.date),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('${day.orderCount} pedidos'),
                        trailing: Text(
                          money(day.total),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        children: day.sales
                            .map((sale) => _SaleTile(sale: sale))
                            .toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: pos.todaySales.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await pos.closeDay();
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Corte guardado. Las ventas permanecen en el historial.',
                              ),
                            ),
                          );
                      },
                icon: const Icon(Icons.archive_outlined),
                label: const Text(
                  'GUARDAR CORTE DE HOY',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasized = false,
    this.valueKey,
  });

  final String label;
  final double value;
  final IconData icon;
  final bool emphasized;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: emphasized ? colors.primaryContainer : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                money(value),
                key: valueKey,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.only(left: 24, right: 16),
      title: Text(
        'Pedido ${timeOfDay(sale.createdAt)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${sale.itemCount} productos'),
      trailing: Text(
        money(sale.total),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      children: sale.lines
          .map(
            (line) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 40, right: 20),
              title: Text('${line.quantity} × ${line.dishName}'),
              subtitle: line.stewName == null && line.tortillaType == null
                  ? null
                  : Text(
                      [
                        if (line.stewName != null) 'Guiso: ${line.stewName}',
                        if (line.tortillaType != null)
                          'Tortilla: ${line.tortillaType}',
                      ].join(' · '),
                    ),
              trailing: Text(money(line.subtotal)),
            ),
          )
          .toList(),
    );
  }
}

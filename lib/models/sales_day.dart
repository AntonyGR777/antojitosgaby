import 'sale.dart';

class SalesDay {
  const SalesDay({required this.date, required this.sales});

  final DateTime date;
  final List<Sale> sales;

  double get total => sales.fold(0, (sum, sale) => sum + sale.total);
  int get orderCount => sales.length;
}

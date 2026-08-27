// La asignación explícita conserva el nombre público `asksForStew` mientras el
// respaldo nullable permite migrar instancias creadas antes de añadir el campo.
// ignore_for_file: prefer_initializing_formals

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.price,
    // Se mantiene público para compatibilidad con el JSON y nullable para
    // instancias antiguas que sobreviven a un hot reload.
    bool? asksForStew,
  }) : _asksForStew = asksForStew;

  final String id;
  final String name;
  final double price;
  // Se conserva únicamente para poder leer datos creados por versiones
  // anteriores. La regla actual depende del nombre del platillo.
  final bool? _asksForStew;
  bool get asksForStew {
    final normalizedName = name.trim().toLowerCase();
    return normalizedName == 'taco' ||
        normalizedName == 'tacos' ||
        normalizedName == 'gordita' ||
        normalizedName == 'gorditas';
  }

  bool get asksForTortilla {
    final normalizedName = name.trim().toLowerCase();
    return normalizedName == 'taco' || normalizedName == 'tacos';
  }

  Dish copyWith({String? name, double? price, bool? asksForStew}) => Dish(
    id: id,
    name: name ?? this.name,
    price: price ?? this.price,
    asksForStew: asksForStew ?? this.asksForStew,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'asksForStew': _asksForStew,
  };

  factory Dish.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return Dish(
      id: json['id'] as String,
      name: name,
      price: (json['price'] as num).toDouble(),
      asksForStew: json['asksForStew'] as bool?,
    );
  }
}

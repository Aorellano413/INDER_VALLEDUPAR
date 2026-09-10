// lib/models/cancha_model.dart
enum TipoCancha { abierta, cerrada, natural, techada, sintetica }

class CanchaModel {
  final String? id;
  final String? sedeId;
  final String image;
  final String title;
  final String price;
  final String horario;
  final TipoCancha tipo;
  final String jugadores;

  CanchaModel({
    this.id,
    this.sedeId,
    required this.image,
    required this.title,
    required this.price,
    required this.horario,
    required this.tipo,
    required this.jugadores,
  });

  factory CanchaModel.fromJson(Map<String, dynamic> json) {
    return CanchaModel(
      id: json['id'],
      sedeId: json['sedeId'],
      image: json['image'] ?? '',
      title: json['title'] ?? '',
      price: json['price'] ?? '',
      horario: json['horario'] ?? '',
      tipo: TipoCancha.values.firstWhere(
        (e) => e.name == json['tipo'],
        orElse: () => TipoCancha.abierta,
      ),
      jugadores: json['jugadores'] ?? '5 vs 5',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (sedeId != null) 'sedeId': sedeId,
      'image': image,
      'title': title,
      'price': price,
      'horario': horario,
      'tipo': tipo.name,
      'jugadores': jugadores,
    };
  }

  CanchaModel copyWith({
    String? id,
    String? sedeId,
    String? image,
    String? title,
    String? price,
    String? horario,
    TipoCancha? tipo,
    String? jugadores,
  }) {
    return CanchaModel(
      id: id ?? this.id,
      sedeId: sedeId ?? this.sedeId,
      image: image ?? this.image,
      title: title ?? this.title,
      price: price ?? this.price,
      horario: horario ?? this.horario,
      tipo: tipo ?? this.tipo,
      jugadores: jugadores ?? this.jugadores,
    );
  }
}
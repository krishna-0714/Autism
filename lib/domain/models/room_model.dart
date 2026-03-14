/// Simple Room domain model
class RoomModel {
  final String id;
  final String name;

  const RoomModel({
    required this.id,
    required this.name,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

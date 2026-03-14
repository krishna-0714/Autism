class SymbolModel {
  final String id;
  final String label;
  final String? roomId;
  final String? imageUrl;
  final String? category;
  final int usageCount;

  const SymbolModel({
    required this.id,
    required this.label,
    this.roomId,
    this.imageUrl,
    this.category,
    this.usageCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'roomId': roomId,
      'imageUrl': imageUrl,
      'category': category,
      'usageCount': usageCount,
    };
  }

  factory SymbolModel.fromJson(Map<String, dynamic> json) {
    return SymbolModel(
      id: json['id'] as String,
      label: json['label'] as String,
      roomId: (json['roomId'] ?? json['room_id']) as String?,
      imageUrl: json['imageUrl'] as String?,
      category: json['category'] as String?,
      usageCount: json['usageCount'] as int? ?? 0,
    );
  }
}

class SmartCategory {
  const SmartCategory({
    required this.id,
    required this.name,
    required this.plannedMonthly,
    required this.remaining,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final double plannedMonthly;
  final double remaining;
  final bool isFavorite;

  factory SmartCategory.fromJson(Map<String, dynamic> json) {
    return SmartCategory(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      plannedMonthly: (json['plannedMonthly'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'plannedMonthly': plannedMonthly,
      'remaining': remaining,
      'isFavorite': isFavorite,
    };
  }
}

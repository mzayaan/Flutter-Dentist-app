class Treatment {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMins;
  final DateTime? createdAt;

  Treatment({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMins,
    this.createdAt,
  });

  factory Treatment.fromJson(Map<String, dynamic> json) {
    return Treatment(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      durationMins: json['duration_mins'] as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'description': description,
        'price': price,
        'duration_mins': durationMins,
      };
}

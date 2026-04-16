class ChatMessageModel {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessageModel.user(String content) => ChatMessageModel(
    id:        DateTime.now().millisecondsSinceEpoch.toString(),
    role:      'user',
    content:   content,
    timestamp: DateTime.now(),
  );

  factory ChatMessageModel.assistant(String content) => ChatMessageModel(
    id:        DateTime.now().millisecondsSinceEpoch.toString(),
    role:      'assistant',
    content:   content,
    timestamp: DateTime.now(),
  );
}

class FoodOptionModel {
  final String id;
  final String name;
  final String cuisine;
  final double rating;
  final String deliveryTime;
  final String priceRange;
  final List<String> tags;
  final String? image;
  final String partner;
  final String? deepLink;
  final double certaintyScore;

  const FoodOptionModel({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.deliveryTime,
    required this.priceRange,
    required this.tags,
    this.image,
    required this.partner,
    this.deepLink,
    required this.certaintyScore,
  });

  factory FoodOptionModel.fromJson(Map<String, dynamic> json) => FoodOptionModel(
    id:             json['id'] ?? '',
    name:           json['name'] ?? '',
    cuisine:        json['cuisine'] ?? '',
    rating:         (json['rating'] as num?)?.toDouble() ?? 0,
    deliveryTime:   json['deliveryTime'] ?? '',
    priceRange:     json['priceRange'] ?? '',
    tags:           List<String>.from(json['tags'] ?? []),
    image:          json['image'],
    partner:        json['partner'] ?? '',
    deepLink:       json['deepLink'],
    certaintyScore: (json['certaintyScore'] as num?)?.toDouble() ?? 0,
  );
}

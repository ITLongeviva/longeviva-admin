import 'package:cloud_firestore/cloud_firestore.dart';

class Ritual {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final int durationDays;
  final String? authorId;
  final String? authorName;
  final String? authorRole;
  final bool isActive;
  final bool isFeatured;
  final int usageCount;
  final List<String> tags;
  final String level;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? imageUrl;

  // Categorie
  static const String categoryAlimentare = 'salute_alimentare';
  static const String categoryMotoria = 'salute_motoria';
  static const String categoryMentale = 'salute_mentale';
  static const String categoryBenessere = 'benessere_generale';

  // Livelli
  static const String levelPrincipiante = 'principiante';
  static const String levelIntermedio = 'intermedio';
  static const String levelAvanzato = 'avanzato';

  static const Map<String, String> categoryLabels = {
    categoryAlimentare: 'Salute Alimentare',
    categoryMotoria: 'Salute Motoria',
    categoryMentale: 'Salute Mentale',
    categoryBenessere: 'Benessere Generale',
  };

  static const Map<String, String> levelLabels = {
    levelPrincipiante: 'Principiante',
    levelIntermedio: 'Intermedio',
    levelAvanzato: 'Avanzato',
  };

  const Ritual({
    required this.id,
    required this.title,
    this.description = '',
    required this.category,
    this.price = 0.0,
    this.durationDays = 7,
    this.authorId,
    this.authorName,
    this.authorRole,
    this.isActive = true,
    this.isFeatured = false,
    this.usageCount = 0,
    this.tags = const [],
    this.level = levelPrincipiante,
    required this.createdAt,
    this.updatedAt,
    this.imageUrl,
  });

  String get categoryLabel => categoryLabels[category] ?? category;
  String get levelLabel => levelLabels[level] ?? level;

  String get formattedPrice =>
      price == 0.0 ? 'Gratuito' : '€${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}';

  factory Ritual.fromJson(Map<String, dynamic> json, String docId) {
    double parsedPrice = 0.0;
    final rawPrice = json['price'];
    if (rawPrice is double) {
      parsedPrice = rawPrice;
    } else if (rawPrice is int) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice) ?? 0.0;
    }

    return Ritual(
      id: docId,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? categoryBenessere,
      price: parsedPrice,
      durationDays: json['durationDays'] as int? ?? 7,
      authorId: json['authorId'] as String?,
      authorName: json['authorName'] as String?,
      authorRole: json['authorRole'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      usageCount: json['usageCount'] as int? ?? 0,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      level: json['level'] as String? ?? levelPrincipiante,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'price': price,
        'durationDays': durationDays,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'isActive': isActive,
        'isFeatured': isFeatured,
        'usageCount': usageCount,
        'tags': tags,
        'level': level,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'imageUrl': imageUrl,
      };
}

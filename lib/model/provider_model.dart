// provider_model.dart
import 'package:flutter/foundation.dart';
import 'dart:convert';

@immutable
class ProviderInfoModel {
  final String name;
  final String username;
  final String category;
  final double rating;
  final int reviews;
  final double ratePerHour;
  final String? imageUrl;

  const ProviderInfoModel({
    required this.name,
    required this.username,
    required this.category,
    required this.rating,
    required this.reviews,
    required this.ratePerHour,
    this.imageUrl,
  });

  /// Convert ProviderInfo to a Map (for storage or serialization)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'category': category,
      'rating': rating,
      'reviews': reviews,
      'ratePerHour': ratePerHour,
      'imageUrl': imageUrl,
    };
  }

  /// Create a ProviderInfo from a Map
  factory ProviderInfoModel.fromMap(Map<String, dynamic> map) {
    return ProviderInfoModel(
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      category: map['category'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      reviews: map['reviews'] ?? 0,
      ratePerHour: (map['ratePerHour'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
    );
  }

  /// Convert ProviderInfo to JSON string
  String toJson() => json.encode(toMap());

  /// Create a ProviderInfo from JSON string
  factory ProviderInfoModel.fromJson(String source) =>
      ProviderInfoModel.fromMap(json.decode(source));

  /// Convert a JSON array into a list of ProviderInfo
  static List<ProviderInfoModel> listFromJson(String source) {
    final decoded = json.decode(source) as List<dynamic>;
    return decoded.map((item) => ProviderInfoModel.fromMap(item)).toList();
  }

  /// Convert a list of ProviderInfo into a JSON array string
  static String listToJson(List<ProviderInfoModel> providers) {
    final mapped = providers.map((p) => p.toMap()).toList();
    return json.encode(mapped);
  }
}
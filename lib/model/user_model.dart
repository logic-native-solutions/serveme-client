class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? city;
  final String? country;
  final String? avatarUrl;


  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.city,
    this.country,
    this.avatarUrl,
    // Initialize other fields
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      city: json['city'] ?? json['address']?['city'],
      country: json['country'] ?? json['address']?['country'],
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'city': city,
      'country': country,
      'avatarUrl': avatarUrl,
    };
  }

  String get locationText {
    final parts = [city, country].where((s) => s != null && s.isNotEmpty);
    return parts.join(', ');
  }
}

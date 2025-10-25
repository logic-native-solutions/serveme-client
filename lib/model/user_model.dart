DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) {
    // Supports ISO-8601 strings like "2025-10-01" or "2025-10-01T12:34:56Z"
    return DateTime.tryParse(v);
  }
  if (v is int) {
    // Supports epoch millis
    return DateTime.fromMillisecondsSinceEpoch(v);
  }
  return null;
}

class UserModel {
  final String id;
  final String firstName;
  final DateTime? dob;
  final String lastName;
  final String? gender;
  final String email;
  final String? phoneNumber;
  final String? city;
  final String? country;
  final bool verified;
  final String? avatarUrl;


  UserModel({
    this.dob,
    required this.id,
    this.gender,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.verified,
    this.phoneNumber,
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
      avatarUrl: json['avatarUrl'] as String?,
      verified: (json['verified'] as bool?) ?? false,
      gender: json['gender'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      // Accepts multiple key variants: date_of_birth, dob, dateOfBirth
      dob: _parseDate(json['date_of_birth']),
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
      'verified': verified,
      'date_of_birth': dob?.toIso8601String(),
    };
  }

  String get locationText {
    final parts = [city, country].where((s) => s != null && (s).isNotEmpty);
    return parts.join(', ');
  }

}

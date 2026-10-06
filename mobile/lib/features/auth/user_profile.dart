class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.role,
    this.facility,
    required this.firstName,
    required this.lastName,
  });

  final int id;
  final String username;
  final String role;
  final int? facility;
  final String firstName;
  final String lastName;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as int,
        username: json['username'] as String,
        role: json['role'] as String,
        facility: json['facility'] as int?,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
      );
}

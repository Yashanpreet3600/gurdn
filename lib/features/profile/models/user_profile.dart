enum UserRole {
  /// Wants protection: sends SOS, shares location, records evidence.
  protected,

  /// Receives alerts and watches live.
  guardian,

  /// Both of the above.
  both;

  bool get isProtected => this != UserRole.guardian;
  bool get isGuardian => this != UserRole.protected;

  static UserRole fromDb(String? value) =>
      UserRole.values.asNameMap()[value] ?? UserRole.protected;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.language,
    required this.onboardingCompleted,
    this.phone,
    this.bloodGroup,
    this.allergies,
    this.medicalNotes,
    this.avatarPath,
  });

  final String id;
  final String fullName;
  final String? phone;
  final UserRole role;
  final String? bloodGroup;
  final String? allergies;
  final String? medicalNotes;
  final String? avatarPath;
  final String language;
  final bool onboardingCompleted;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['id'] as String,
        fullName: (m['full_name'] as String?) ?? '',
        phone: m['phone'] as String?,
        role: UserRole.fromDb(m['role'] as String?),
        bloodGroup: m['blood_group'] as String?,
        allergies: m['allergies'] as String?,
        medicalNotes: m['medical_notes'] as String?,
        avatarPath: m['avatar_path'] as String?,
        language: (m['language'] as String?) ?? 'en',
        onboardingCompleted: (m['onboarding_completed'] as bool?) ?? false,
      );
}

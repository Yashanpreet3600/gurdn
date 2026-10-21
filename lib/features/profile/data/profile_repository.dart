import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  ProfileRepository._();
  static final instance = ProfileRepository._();

  static const _table = 'profiles';
  static const _avatarBucket = 'avatars';

  SupabaseClient get _db => SupabaseService.client;

  // ---- Cached copy, so home (and later SOS) works without internet ----

  static UserRole? get cachedRole {
    final value = LocalStore.getString(LocalKeys.cachedRole);
    return value == null ? null : UserRole.fromDb(value);
  }

  static String? get cachedName => LocalStore.getString(LocalKeys.cachedName);

  static bool get cachedOnboardingCompleted =>
      LocalStore.getBool(LocalKeys.cachedOnboardingDone);

  /// Name used in SMS messages.
  static String get myDisplayName {
    final cached = cachedName;
    if (cached != null && cached.isNotEmpty) return cached;
    return (SupabaseService.currentUser?.userMetadata?['full_name'] as String?) ?? '';
  }

  // ---- Reads ----

  Future<UserProfile?> fetchMine() async {
    final row = await _db.from(_table).select().eq('id', SupabaseService.uid).maybeSingle();
    if (row == null) return null;
    final profile = UserProfile.fromMap(row);
    await _cache(profile);
    return profile;
  }

  Future<void> _cache(UserProfile p) async {
    await LocalStore.setString(LocalKeys.cachedRole, p.role.name);
    await LocalStore.setString(LocalKeys.cachedName, p.fullName);
    await LocalStore.setBool(LocalKeys.cachedOnboardingDone, p.onboardingCompleted);
  }

  // ---- Writes ----

  /// Creates the row if the sign-up trigger didn't, using the sign-up details.
  Future<void> saveBasics({required String fullName, required String phone}) async {
    final meta = SupabaseService.currentUser?.userMetadata ?? const <String, dynamic>{};
    await _db.from(_table).upsert({
      'id': SupabaseService.uid,
      'full_name': fullName,
      'phone': phone,
      'role': UserRole.fromDb(meta['role'] as String?).name,
    });
    await LocalStore.setString(LocalKeys.cachedName, fullName);
  }

  Future<void> saveSafetyProfile({
    required String fullName,
    required String phone,
    String? bloodGroup,
    String? allergies,
    String? medicalNotes,
    String? avatarPath,
  }) async {
    await _db.from(_table).update({
      'full_name': fullName,
      'phone': phone,
      'blood_group': bloodGroup,
      'allergies': _blankToNull(allergies),
      'medical_notes': _blankToNull(medicalNotes),
      'avatar_path': avatarPath,
    }).eq('id', SupabaseService.uid);
    await LocalStore.setString(LocalKeys.cachedName, fullName);
  }

  Future<void> markOnboardingComplete() async {
    await _db.from(_table).update({'onboarding_completed': true}).eq('id', SupabaseService.uid);
    await LocalStore.setBool(LocalKeys.cachedOnboardingDone, true);
  }

  Future<void> updateLanguage(String code) async {
    await _db.from(_table).update({'language': code}).eq('id', SupabaseService.uid);
  }

  // ---- Photo ----

  Future<String> uploadAvatar(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '${SupabaseService.uid}/avatar.$ext';
    await _db.storage.from(_avatarBucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  /// Temporary link to the private photo, valid for one hour.
  Future<String?> avatarUrl(String? path) async {
    if (path == null) return null;
    try {
      return await _db.storage.from(_avatarBucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  static String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

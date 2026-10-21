import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../profile/models/user_profile.dart';
import '../../security/pin_service.dart';

/// Email + password accounts through Supabase Auth.
/// Codes are emailed (6 digits), so no deep links are needed.
class AuthRepository {
  AuthRepository._();
  static final instance = AuthRepository._();

  GoTrueClient get _auth => SupabaseService.client.auth;

  bool get isSignedIn => _auth.currentSession != null;

  static bool isEmailNotConfirmed(AuthException e) =>
      e.message.toLowerCase().contains('not confirmed');

  /// Returns true if the user must enter the emailed code next.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      // Saved as user metadata; a database trigger copies it into `profiles`.
      data: {
        'full_name': name.trim(),
        'phone': phone,
        'role': role.name,
        'language': LocaleController.instance.value.languageCode,
      },
    );

    // Supabase hides existing accounts by returning a user with no identities.
    final identities = response.user?.identities;
    if (response.user != null && identities != null && identities.isEmpty) {
      throw EmailAlreadyRegisteredException();
    }
    return response.session == null;
  }

  Future<void> verifySignupCode(String email, String code) async {
    await _auth.verifyOTP(type: OtpType.signup, email: email.trim(), token: code.trim());
  }

  Future<void> resendSignupCode(String email) async {
    await _auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> sendPasswordResetCode(String email) async {
    await _auth.resetPasswordForEmail(email.trim());
  }

  /// Checks the emailed code (which signs the user in), then sets the new password.
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _auth.verifyOTP(type: OtpType.recovery, email: email.trim(), token: code.trim());
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  /// PINs and cached data are removed from this phone too.
  Future<void> signOut() async {
    await PinService.clear();
    await LocalStore.clearUserData();
    try {
      await _auth.signOut();
    } catch (_) {
      // The local session is cleared even if the server can't be reached.
    }
  }

  /// Deletes the account and all data through the `delete-account` Edge Function,
  /// because deleting a user needs the secret key, which never goes in the app.
  Future<void> deleteAccount() async {
    await SupabaseService.client.functions.invoke('delete-account');
    await signOut();
  }
}

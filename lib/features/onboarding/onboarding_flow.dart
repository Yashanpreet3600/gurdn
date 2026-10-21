import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/local_store.dart';
import '../contacts/data/contacts_repository.dart';
import '../profile/data/profile_repository.dart';
import '../profile/models/user_profile.dart';
import '../security/pin_service.dart';

/// Decides which screen comes next, so setup resumes where it stopped
/// (for example, if the app was closed halfway through).
///
/// Setup steps: 1 profile, 2 contacts, 3 permissions, 4 PINs, 5 test alert.
/// Guardian-only users do just the profile.
class OnboardingFlow {
  OnboardingFlow._();

  static const totalSteps = 5;

  static Future<String> nextRoute() async {
    final profile = await ProfileRepository.instance.fetchMine();
    if (profile == null) return AppRoutes.safetyProfile;

    final protects = profile.role.isProtected;

    if (!profile.onboardingCompleted) {
      if (!LocalStore.getBool(LocalKeys.obProfileDone)) return AppRoutes.safetyProfile;

      if (!protects) {
        await ProfileRepository.instance.markOnboardingComplete();
        return AppRoutes.guardianHome;
      }

      final primaryContacts = await ContactsRepository.instance.countPrimary();
      if (primaryContacts < AppConfig.minPrimaryContacts) return AppRoutes.contactsSetup;
      if (!LocalStore.getBool(LocalKeys.obPermissionsDone)) return AppRoutes.permissions;
      if (!await PinService.hasPins()) return AppRoutes.pinSetup;
      return AppRoutes.testAlert;
    }

    // Setup was finished before, but PINs live only on this phone,
    // so a new phone or a reinstall needs them again.
    if (protects && !await PinService.hasPins()) return AppRoutes.pinSetup;
    return protects ? AppRoutes.home : AppRoutes.guardianHome;
  }

  static Future<void> goNext(BuildContext context) async {
    String route;
    try {
      route = await nextRoute();
    } catch (_) {
      // No internet. If this phone finished setup before, open home anyway
      // so the SOS button is always reachable.
      if (!ProfileRepository.cachedOnboardingCompleted) rethrow;
      final role = ProfileRepository.cachedRole ?? UserRole.protected;
      route = role.isProtected ? AppRoutes.home : AppRoutes.guardianHome;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }
}

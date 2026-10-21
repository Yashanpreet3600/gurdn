import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';
import '../models/sos_settings.dart';

class SosSettingsRepository {
  SosSettingsRepository._();
  static final instance = SosSettingsRepository._();

  static const _table = 'sos_settings';

  SupabaseClient get _db => SupabaseService.client;

  /// Instant, offline copy. Used the moment SOS is pressed.
  SosSettings get cached {
    final raw = LocalStore.getString(LocalKeys.cachedSosSettings);
    if (raw == null) return SosSettings.defaults;
    try {
      return SosSettings.fromMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return SosSettings.defaults;
    }
  }

  /// Latest settings from the server; falls back to the phone copy when offline.
  Future<SosSettings> load() async {
    try {
      final row = await _db
          .from(_table)
          .select()
          .eq('user_id', SupabaseService.uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (row == null) {
        // Row missing (account made before the sign-up trigger): create it.
        await _db.from(_table).upsert({
          'user_id': SupabaseService.uid,
          ...SosSettings.defaults.toMap(),
        });
        await _cache(SosSettings.defaults);
        return SosSettings.defaults;
      }
      final settings = SosSettings.fromMap(row);
      await _cache(settings);
      return settings;
    } catch (_) {
      return cached;
    }
  }

  Future<void> save(SosSettings settings) async {
    await _cache(settings);
    await _db.from(_table).update(settings.toMap()).eq('user_id', SupabaseService.uid);
  }

  Future<void> _cache(SosSettings s) async {
    await LocalStore.setString(LocalKeys.cachedSosSettings, jsonEncode(s.toMap()));
  }
}

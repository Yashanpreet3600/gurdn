import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';
import '../models/emergency_contact.dart';

class ContactsRepository {
  ContactsRepository._();
  static final instance = ContactsRepository._();

  static const _table = 'emergency_contacts';

  SupabaseClient get _db => SupabaseService.client;

  /// Link sent in the invite SMS. The guardian web page handles it.
  static String inviteLink(String token) => '${AppConfig.guardianWebBase}/invite/$token';

  /// Accepts a full invite link or just the code. Returns null if invalid.
  static String? extractToken(String input) {
    var text = input.trim();
    final i = text.indexOf('/invite/');
    if (i >= 0) text = text.substring(i + '/invite/'.length);
    text = text.split(RegExp(r'[?#/\s]')).first.toLowerCase();
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(text) ? text : null;
  }

  // ---- The user's own contacts ----

  Future<List<EmergencyContact>> fetchMine() async {
    final rows = await _db
        .from(_table)
        .select()
        .eq('user_id', SupabaseService.uid)
        .order('is_backup', ascending: true)
        .order('priority', ascending: true)
        .order('created_at', ascending: true);
    final contacts = rows.map(EmergencyContact.fromMap).toList();
    await _cache(contacts);
    return contacts;
  }

  // ---- Offline copy, so SOS can text contacts without internet ----

  List<EmergencyContact> get cachedContacts {
    final raw = LocalStore.getString(LocalKeys.cachedContacts);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cache(List<EmergencyContact> contacts) async {
    await LocalStore.setString(
      LocalKeys.cachedContacts,
      jsonEncode(contacts.map((c) => c.toMap()).toList()),
    );
  }

  Future<int> countPrimary() async {
    final contacts = await fetchMine();
    return contacts.where((c) => !c.isBackup).length;
  }

  Future<EmergencyContact> add(ContactDraft draft) async {
    final existing = await fetchMine();
    final row = await _db
        .from(_table)
        .insert({
          'user_id': SupabaseService.uid,
          'name': draft.name,
          'phone': draft.phone,
          'relation': draft.relation,
          'is_backup': draft.isBackup,
          'priority': existing.length,
          if (draft.email != null && draft.email!.isNotEmpty) 'email': draft.email,
        })
        .select()
        .single();
    return EmergencyContact.fromMap(row);
  }

  Future<void> markInviteSent(String contactId) async {
    await _db
        .from(_table)
        .update({'invite_sent_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', contactId);
  }

  /// Set or clear the optional email (null clears it).
  Future<void> setEmail(String contactId, String? email) async {
    final value = (email == null || email.trim().isEmpty) ? null : email.trim();
    await _db.from(_table).update({'email': value}).eq('id', contactId);
  }

  Future<void> setBackup(String contactId, bool isBackup) async {
    await _db.from(_table).update({'is_backup': isBackup}).eq('id', contactId);
  }

  Future<void> remove(String contactId) async {
    await _db.from(_table).delete().eq('id', contactId);
  }

  // ---- Guardian side ----

  /// People who added the signed-in user as a guardian and whose invite they accepted.
  Future<List<ProtectedPerson>> fetchPeopleIProtect() async {
    final rows = await _db
        .from(_table)
        .select('id, user_id, relation, profiles(full_name, phone)')
        .eq('guardian_user_id', SupabaseService.uid)
        .eq('invite_status', 'accepted');
    return rows.map(ProtectedPerson.fromMap).toList();
  }

  /// Accepts an invite inside the app. Returns the name of the person who sent it.
  Future<String> acceptInvite(String token) async {
    final result = await _db.rpc('accept_invite', params: {'p_token': token});
    return (result as String?) ?? '';
  }
}

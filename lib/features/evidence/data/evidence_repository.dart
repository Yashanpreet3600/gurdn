import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';

/// Stores evidence captured during an SOS: the file is kept on the phone
/// and uploaded to private Supabase Storage; a row with a
/// tamper-proof SHA-256 fingerprint goes to Supabase.
///
/// Everything is best-effort and offline-tolerant: if the upload can't
/// finish now (no internet, no Worker), the local file path is queued and
/// retried later. The fingerprint is computed at capture time, so the
/// report can prove the file wasn't changed afterwards.
class EvidenceRepository {
  EvidenceRepository._();
  static final instance = EvidenceRepository._();

  static const _bucket = 'evidence';

  /// Capture done: fingerprint the file, record it, and try to upload.
  /// [localPath] is the file on disk; [kind] is audio/video/photo.
  Future<void> capture({
    required String localPath,
    required String kind,
    required String eventId,
    int? durationMs,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) return;

    final bytes = await file.length();
    final digest = await _sha256(file);
    final uid = SupabaseService.uid;
    final name = localPath.split('/').last;
    final key = '$uid/$eventId/$name';

    // 1. Record the row (pending). Works offline via the normal queue? No —
    // this is a direct insert; if it fails we still queue the file so the
    // row + upload are retried together.
    var rowInserted = false;
    try {
      await SupabaseService.client.from('evidence').insert({
        'user_id': uid,
        'event_id': eventId,
        'kind': kind,
        'storage_key': key,
        'sha256': digest,
        'bytes': bytes,
        if (durationMs != null) 'duration_ms': durationMs,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      });
      rowInserted = true;
    } catch (_) {}

    // 2. Upload the bytes to R2.
    final uploaded = await _upload(key, kind, file);

    if (uploaded && rowInserted) {
      try {
        await SupabaseService.client
            .from('evidence')
            .update({'upload_status': 'uploaded', 'uploaded_at': DateTime.now().toUtc().toIso8601String()})
            .eq('storage_key', key);
      } catch (_) {}
    } else {
      _queue(_QueuedEvidence(
        localPath: localPath, kind: kind, eventId: eventId, key: key,
        sha256: digest, bytes: bytes, durationMs: durationMs,
        rowInserted: rowInserted,
      ));
    }
  }

  /// Retry everything queued (call on reconnect / app start).
  Future<void> flushQueue() async {
    final queue = _loadQueue();
    if (queue.isEmpty) return;
    final remaining = <_QueuedEvidence>[];
    for (final q in queue) {
      final file = File(q.localPath);
      if (!await file.exists()) continue; // file gone; drop it
      var ok = true;
      if (!q.rowInserted) {
        try {
          await SupabaseService.client.from('evidence').insert({
            'user_id': SupabaseService.uid, 'event_id': q.eventId, 'kind': q.kind,
            'storage_key': q.key, 'sha256': q.sha256, 'bytes': q.bytes,
            if (q.durationMs != null) 'duration_ms': q.durationMs,
            'captured_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {
          ok = false;
        }
      }
      if (ok && await _upload(q.key, q.kind, file)) {
        try {
          await SupabaseService.client.from('evidence')
              .update({'upload_status': 'uploaded', 'uploaded_at': DateTime.now().toUtc().toIso8601String()})
              .eq('storage_key', q.key);
        } catch (_) {}
      } else {
        remaining.add(q);
      }
    }
    _saveQueue(remaining);
  }

  /// A short-lived URL a guardian/owner can open to view one clip.
  /// Storage rules only let the owner and their guardians create it.
  Future<String?> downloadUrl(String storageKey) async {
    try {
      return await SupabaseService.client.storage.from(_bucket).createSignedUrl(storageKey, 300);
    } catch (_) {
      return null;
    }
  }

  // ---- internals ----

  /// Uploads to the private Supabase Storage bucket "evidence".
  /// Free plan: 1 GB total, 50 MB per file. A file that fails stays on the
  /// phone and is retried by [flushQueue].
  Future<bool> _upload(String key, String kind, File file) async {
    try {
      await SupabaseService.client.storage.from(_bucket).upload(
            key,
            file,
            fileOptions: FileOptions(contentType: _mime(kind), upsert: true),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _mime(String kind) => switch (kind) {
        'audio' => 'audio/mp4',
        'video' => 'video/mp4',
        'photo' => 'image/jpeg',
        _ => 'application/octet-stream',
      };

  Future<String> _sha256(File file) async {
    // Streams the file, so a large video never loads fully into memory.
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  List<_QueuedEvidence> _loadQueue() {
    final raw = LocalStore.getString(LocalKeys.evidenceQueue);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => _QueuedEvidence.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _saveQueue(List<_QueuedEvidence> q) =>
      LocalStore.setString(LocalKeys.evidenceQueue, jsonEncode(q.map((e) => e.toJson()).toList()));

  void _queue(_QueuedEvidence item) {
    final q = _loadQueue()..add(item);
    _saveQueue(q);
  }
}

class _QueuedEvidence {
  _QueuedEvidence({
    required this.localPath,
    required this.kind,
    required this.eventId,
    required this.key,
    required this.sha256,
    required this.bytes,
    required this.rowInserted,
    this.durationMs,
  });

  final String localPath;
  final String kind;
  final String eventId;
  final String key;
  final String sha256;
  final int bytes;
  final int? durationMs;
  final bool rowInserted;

  Map<String, dynamic> toJson() => {
        'localPath': localPath, 'kind': kind, 'eventId': eventId, 'key': key,
        'sha256': sha256, 'bytes': bytes, 'durationMs': durationMs, 'rowInserted': rowInserted,
      };

  factory _QueuedEvidence.fromJson(Map<String, dynamic> m) => _QueuedEvidence(
        localPath: m['localPath'] as String,
        kind: m['kind'] as String,
        eventId: m['eventId'] as String,
        key: m['key'] as String,
        sha256: m['sha256'] as String,
        bytes: (m['bytes'] as num).toInt(),
        durationMs: (m['durationMs'] as num?)?.toInt(),
        rowInserted: (m['rowInserted'] as bool?) ?? false,
      );
}

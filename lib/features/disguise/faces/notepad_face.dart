import 'package:flutter/material.dart';

import '../../../core/services/local_store.dart';
import 'face_actions.dart';
import 'secret_entry.dart';

/// A working notepad. Its text is really saved. Typing your safety PIN (or
/// 112 + PIN for a silent SOS) on its own line, then leaving that line,
/// triggers the secret action and removes the line so nothing shows.
class NotepadFace extends StatefulWidget {
  const NotepadFace({super.key});

  @override
  State<NotepadFace> createState() => _NotepadFaceState();
}

class _NotepadFaceState extends State<NotepadFace> {
  late final TextEditingController _c =
      TextEditingController(text: LocalStore.getString(LocalKeys.disguiseNotes) ?? '');
  bool _checking = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String text) async {
    LocalStore.setString(LocalKeys.disguiseNotes, text);
    if (_checking) return;

    // Look at the line the cursor just finished (the one before a new line,
    // or the last line). Only digits are considered.
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final digits = lines[i].replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 4) continue;
      _checking = true;
      final action = await SecretEntry.evaluate(digits);
      _checking = false;
      if (action != SecretAction.none) {
        // Remove the secret line so the note looks untouched.
        lines.removeAt(i);
        final cleaned = lines.join('\n');
        _c.text = cleaned;
        LocalStore.setString(LocalKeys.disguiseNotes, cleaned);
        if (mounted) await FaceActions.handle(context, action);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Notes'), elevation: 0),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _c,
            onChanged: _onChanged,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Write a note…',
            ),
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}

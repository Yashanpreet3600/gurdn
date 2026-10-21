import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';

/// Shown instead of the app when it is opened in Chrome or on a computer.
///
/// SOS needs SMS, GPS and Android background services, none of which exist
/// there, so the real app would fail in confusing ways. In debug builds a
/// "preview" button still lets the developer look at the screens.
class UnsupportedPlatformApp extends StatelessWidget {
  const UnsupportedPlatformApp({super.key, this.onPreview});

  /// Only set in debug builds.
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.instance.value.languageCode;
    String t(String key) => AppStrings.get(key, lang);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_android, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      t('unsupported_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(t('unsupported_body'), textAlign: TextAlign.center),
                    if (onPreview != null) ...[
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: onPreview,
                        child: Text(t('unsupported_preview')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

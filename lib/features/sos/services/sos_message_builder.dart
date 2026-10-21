import '../../../core/localization/app_strings.dart';
import 'location_service.dart';

/// Builds every SOS text message. Messages are kept short because each
/// SMS part costs money, and Hindi fits only 70 characters per part.
class SosMessageBuilder {
  SosMessageBuilder({required this.language, required this.name, required this.isTest});

  /// 'en', 'hi' or 'pa', from SOS settings (independent of the app language).
  final String language;
  final String name;
  final bool isTest;

  String _t(String key) => AppStrings.get(key, language);

  String _fill(String key, Map<String, String> args) {
    var text = _t(key);
    args.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }

  String get _prefix => isTest ? _t('sms_test_prefix') : '';

  static String time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _where(GxPosition? p) {
    if (p == null) return _t('sms_location_pending');
    final args = {'link': p.mapsLink, 'm': '${p.accuracy.round()}'};
    // A location older than 2 minutes is labelled, so nobody searches the wrong place.
    if (p.age > const Duration(minutes: 2)) {
      return _fill('sms_location_old', {...args, 'min': '${p.age.inMinutes}'});
    }
    return _fill('sms_location', args);
  }

  /// First message: goes out instantly, before a fresh GPS fix.
  String initial({
    required String levelMessage,
    required GxPosition? position,
    required int? battery,
    required String? trackLink,
    required DateTime at,
  }) {
    final lines = <String>[
      '$_prefix$levelMessage',
      _fill('sms_from', {'name': name, 'time': time(at)}),
      _where(position),
      if (battery != null) _fill('sms_battery', {'b': '$battery'}),
      if (trackLink != null) _fill('sms_track', {'link': trackLink}),
    ];
    return lines.join('\n');
  }

  String precise(GxPosition p) => _prefix +
      _fill('sms_precise', {
        'name': name,
        'link': p.mapsLink,
        'm': '${p.accuracy.round()}',
        'time': time(p.at),
      });

  String update(GxPosition p) => _prefix +
      _fill('sms_update', {
        'name': name,
        'link': p.mapsLink,
        'm': '${p.accuracy.round()}',
        'time': time(p.at),
      });

  String escalation({required int minutes, required GxPosition? position}) =>
      '$_prefix${_fill('sms_escalation', {'name': name, 'min': '$minutes'})}\n${_where(position)}';

  String duress(GxPosition? position) =>
      '$_prefix${_fill('sms_duress', {'name': name})}\n${_where(position)}';

  /// One last SMS when the battery hits 5%, so guardians have the final
  /// location before the phone dies.
  String lowBattery(GxPosition? position, int battery) =>
      '$_prefix${_fill('sms_low_battery', {'name': name, 'b': '$battery'})}\n${_where(position)}';

  String safe(DateTime at) => _prefix + _fill('sms_safe', {'name': name, 'time': time(at)});
}

import 'package:flutter/widgets.dart';

import '../services/local_store.dart';
import 'strings_pa.dart';
import 'strings_phase2.dart';
import 'strings_phase34.dart';
import 'strings_phase5.dart';
import 'strings_phase6.dart';
import 'strings_phase7.dart';
import 'strings_phase8.dart';
import 'strings_sos.dart';

/// Holds the chosen language and rebuilds the app when it changes.
class LocaleController extends ValueNotifier<Locale> {
  LocaleController._() : super(const Locale('en'));

  static final instance = LocaleController._();

  void load() {
    final code = LocalStore.getString(LocalKeys.language);
    if (code != null && AppStrings.isSupported(code)) value = Locale(code);
  }

  Future<void> setLanguage(String code) async {
    if (!AppStrings.isSupported(code)) return;
    value = Locale(code);
    await LocalStore.setString(LocalKeys.language, code);
  }
}

extension AppStringsX on BuildContext {
  /// Text for [key] in the current language. Falls back to English.
  String tr(String key) => AppStrings.get(key, Localizations.localeOf(this).languageCode);

  /// Same as [tr], replacing {placeholders} with [args].
  String trArgs(String key, Map<String, String> args) {
    var text = tr(key);
    args.forEach((name, value) => text = text.replaceAll('{$name}', value));
    return text;
  }
}

/// All screen text in English, Hindi and Punjabi.
/// To add a language: add its code to [supportedLocales] and a map to each table.
class AppStrings {
  AppStrings._();

  static const supportedLocales = [Locale('en'), Locale('hi'), Locale('pa')];

  /// Display names, each in its own script, for language pickers.
  static const languageNames = {'en': 'English', 'hi': 'हिन्दी', 'pa': 'ਪੰਜਾਬੀ'};

  static bool isSupported(String code) => languageNames.containsKey(code);

  /// Every table, searched in order: screens, SOS, Phase 2.
  static const _tables = [_values, sosStrings, phase2Strings, phase34Strings, phase5Strings, phase6Strings, phase7Strings, phase8Strings];

  /// Text for [key] in [languageCode], else English, else the key itself.
  static String get(String key, String languageCode) {
    for (final table in _tables) {
      final text = table[languageCode]?[key];
      if (text != null) return text;
    }
    for (final table in _tables) {
      final text = table['en']?[key];
      if (text != null) return text;
    }
    return key;
  }

  /// True if [key] has its own text in [languageCode] (not an English fallback).
  static bool has(String key, String languageCode) =>
      _tables.any((t) => t[languageCode]?.containsKey(key) ?? false);

  /// Every key that exists in English (used by tests to check translations).
  static Set<String> get allKeys => {for (final t in _tables) ...t['en']!.keys};

  static const Map<String, Map<String, String>> _values = {
    'en': {
      // Common
      'continue': 'Continue',
      'continue_anyway': 'Continue anyway',
      'done': 'Done',
      'cancel': 'Cancel',
      'save': 'Save',
      'saved': 'Saved',
      'skip': 'Skip',
      'skip_for_now': 'Skip for now',
      'remove': 'Remove',
      'delete': 'Delete',
      'allow': 'Allow',
      'allow_all': 'Allow all',
      'open_settings': 'Open settings',
      'essential': 'Essential',
      'backup': 'Backup',
      'settings': 'Settings',
      'retry': 'Try again',
      'step_of': 'Step {n} of {total}',
      'name': 'Name',
      'full_name': 'Full name',
      'email': 'Email',
      'phone': 'Phone number',
      'password': 'Password',
      'confirm_password': 'Confirm password',
      'new_password': 'New password',

      // Errors
      'err_required': 'This field is required',
      'err_email': 'Enter a valid email address',
      'err_password': 'Use at least 8 characters',
      'err_password_match': "Passwords don't match",
      'err_phone': 'Enter a valid phone number',
      'err_code': 'Enter the full code from your email',
      'err_consent': 'Accept the privacy terms to continue',
      'err_offline': 'No internet connection. Check your network and try again.',
      'err_generic': 'Something went wrong. Try again.',
      'err_duplicate': 'This number is already in your list',
      'err_invite_not_found': "This invite isn't valid. Ask for a new one.",
      'err_own_invite': "You can't accept your own invite.",
      'err_invite_used': 'Someone else already accepted this invite.',
      'err_contact_limit': 'You can add up to 5 main and 3 backup contacts.',
      'err_not_signed_in': 'Please sign in again.',
      'already_registered': 'This email already has an account. Log in instead.',
      'config_missing_title': 'App not configured',
      'config_missing_body':
          'The Supabase keys are missing. Run the app with --dart-define-from-file=env.json as described in SETUP.md.',

      // Welcome and role
      'welcome_tagline': 'One tap alerts the people you trust, with your live location.',
      'privacy_title': 'Your privacy comes first',
      'privacy_body':
          'Your location, recordings and medical details are shared only with the guardians you choose, and only during an emergency. You can delete everything at any time.',
      'get_started': 'Get started',
      'have_account': 'I already have an account',
      'role_title': 'How will you use GuardianX?',
      'role_subtitle': 'Choose the option that fits you best.',
      'role_protected': 'I want protection',
      'role_protected_desc': 'Send SOS alerts, share your live location and record evidence.',
      'role_guardian': "I'm a guardian",
      'role_guardian_desc': 'Get alerts and watch live when someone you protect needs help.',
      'role_both': 'Both',
      'role_both_desc': 'Stay protected and look out for others too.',

      // Sign up, verify, login, reset
      'signup_title': 'Create your account',
      'consent_text':
          'I agree that GuardianX stores my details to protect me and shares them with my guardians only during an emergency.',
      'create_account': 'Create account',
      'verify_title': 'Verify your email',
      'verify_body': 'We sent a {n}-digit code to {email}. Enter it below.',
      'verify': 'Verify',
      'resend_code': 'Resend code',
      'resend_in': 'Resend code in {s} s',
      'code_resent': 'A new code is on its way',
      'check_spam': "Can't find it? Check your spam folder.",
      'login_title': 'Welcome back',
      'login': 'Log in',
      'forgot_password': 'Forgot password?',
      'no_account': 'Create a new account',
      'email_not_confirmed': "Your email isn't verified yet. We sent you a new code.",
      'reset_title': 'Reset password',
      'reset_body': "Enter your account email and we'll send you a 6-digit code.",
      'reset_enter_code': 'Enter the code from your email and choose a new password.',
      'send_code': 'Send code',
      'reset_code_sent': 'Code sent to {email}',
      'reset_password': 'Reset password',
      'password_updated': 'Password updated',

      // Safety profile
      'safety_profile': 'Safety profile',
      'profile_title': 'Your safety profile',
      'profile_subtitle':
          'Guardians and responders see this during an SOS. Only name and phone are required.',
      'profile_photo_hint': 'Add a photo so guardians can identify you',
      'blood_group': 'Blood group',
      'allergies': 'Allergies',
      'allergies_hint': 'For example penicillin or peanuts',
      'medical_notes': 'Medical notes',
      'medical_hint': 'Conditions, medicines, anything a responder should know',
      'profile_privacy': 'Shared only with your guardians, and only during an active SOS.',
      'save_continue': 'Save and continue',
      'profile_incomplete': 'Add blood group and medical notes',

      // Contacts
      'emergency_contacts': 'Emergency contacts',
      'contacts_title': 'Who should we alert?',
      'contacts_subtitle':
          'Add at least one main contact. Backup contacts are alerted if no one responds.',
      'contacts_empty': 'No contacts yet',
      'pick_contact': 'Pick from phone contacts',
      'enter_manually': 'Type a number',
      'contacts_info':
          'Each contact gets an SMS invite to accept. People who agree in advance are far more likely to act in an emergency.',
      'contacts_need_one': 'Add at least one main contact to continue',
      'contacts_permission_denied': 'Contacts access is off. You can type the number instead.',
      'contacts_limit': 'You can add up to 5 main and 3 backup contacts',
      'contact_details': 'Contact details',
      'choose_number': 'Choose a number',
      'relation': 'Relation',
      'rel_parent': 'Parent',
      'rel_sibling': 'Sibling',
      'rel_partner': 'Partner',
      'rel_friend': 'Friend',
      'rel_relative': 'Relative',
      'rel_other': 'Other',
      'backup_contact': 'Backup contact',
      'backup_contact_desc': 'Alerted only if no main contact responds',
      'save_send_invite': 'Save and send invite',
      'invite_sms':
          '{name} would like you to be an emergency contact. If anything ever happens, you may get a text with a location link. You can accept here: {link}',
      'invite_sms_denied': "SMS permission is off, so the invite wasn't sent. You can send it later.",
      'invite_sent': 'Invite sent to {name}',
      'invite_failed': "Couldn't send the invite to {name}",
      'status_accepted': 'Accepted',
      'status_declined': 'Declined',
      'status_waiting': 'Waiting for reply',
      'status_not_sent': 'Invite not sent',
      'resend_invite': 'Send invite again',
      'make_primary': 'Make main contact',
      'make_backup': 'Make backup contact',
      'remove_contact': 'Remove contact?',
      'remove_contact_body': '{name} will no longer get your alerts.',

      // Permissions
      'perm_title': 'Allow what SOS needs',
      'perm_subtitle':
          'Each permission is used only for your safety. You can change them anytime in Settings.',
      'perm_location': 'Location',
      'perm_location_why': 'Sends your exact location to guardians during an SOS.',
      'perm_bg_location': 'Location all the time',
      'perm_bg_location_why':
          'Keeps tracking when the screen is off. Choose "Allow all the time" on the next screen.',
      'perm_camera': 'Camera',
      'perm_camera_why': 'Live video for guardians and evidence recording.',
      'perm_mic': 'Microphone',
      'perm_mic_why': 'Live audio and audio evidence.',
      'perm_sms': 'SMS',
      'perm_sms_why': 'Sends alerts automatically from your SIM, even without internet.',
      'perm_notif': 'Notifications',
      'perm_notif_why': 'Shows SOS status and when a guardian is on the way.',
      'perm_battery': 'No battery restrictions',
      'perm_battery_why': 'Stops Android from closing GuardianX in the background.',
      'perm_location_first': 'Allow Location first',
      'perm_missing_title': "SOS won't work fully",
      'perm_missing_body':
          'Without location and SMS, your guardians may not get your alert or your location. Continue anyway?',
      'permissions_settings': 'Permissions',

      // PINs
      'change_pins': 'Change PINs',
      'pin_current_title': 'Enter your current safety PIN',
      'pin_safe_title': 'Create your safety PIN',
      'pin_safe_body':
          "You'll need this 4-digit PIN to stop an SOS, so an attacker can't cancel it.",
      'pin_confirm_title': 'Enter it again',
      'pin_confirm_safe_body': 'Confirm your safety PIN.',
      'pin_confirm_duress_body': 'Confirm your duress PIN.',
      'pin_duress_title': 'Create a duress PIN',
      'pin_duress_body': 'A second, different PIN for when someone forces you to stop the SOS.',
      'pin_duress_how_title': 'How the duress PIN works',
      'pin_duress_how':
          'The screen will look like the SOS stopped, but your guardians keep getting your location and a warning that you were forced to cancel.',
      'pin_wrong': 'Wrong PIN',
      'pin_weak': 'Too easy to guess. Avoid repeated or sequential digits.',
      'pin_mismatch': "PINs didn't match. Start again.",
      'pin_same': 'The duress PIN must be different from your safety PIN',
      'pins_saved': 'PINs saved',

      // Test alert
      'test_title': 'Send a test alert',
      'test_subtitle':
          'Check that your contacts receive messages from you. Every message is marked TEST.',
      'test_preview': 'Message preview',
      'test_sms':
          "TEST from GuardianX: {name} has set you as an emergency contact. This is only a test, so no action is needed. In a real emergency you'll get a message like this with a live link.",
      'send_test': 'Send test alert',
      'send_again': 'Send again',
      'finish_setup': 'Finish setup',
      'skip_test_title': 'Skip the test?',
      'skip_test_body':
          'The test is the only way to know your alerts actually reach your contacts.',
      'test_cost_note': 'Messages go from your SIM. Normal SMS charges on your plan apply.',
      'sms_permission_needed': 'Allow SMS permission to send the test',
      'sms_sent': 'Sent',
      'sms_failed': 'Failed',
      'test_ask_contacts': 'Ask your contacts whether the message arrived.',

      // Home
      'hello': 'Hi, {name}',
      'sos_hint': 'Your guardians are alerted the moment you press SOS.',
      'sos_not_active': 'Not active yet',
      'contacts_accepted_count': '{accepted} of {total} accepted',
      'helplines': 'Helplines',
      'helpline_112': 'Emergency',
      'helpline_1091': 'Women (police)',
      'helpline_181': 'Women (support)',
      'people_i_protect': 'People I protect',

      // Guardian
      'guardian_title': 'Guardian',
      'guardian_info':
          "When someone you protect sends an SOS, you'll get an SMS with a live link to their video and location.",
      'accept_invite_title': 'Got an invite?',
      'invite_code_label': 'Paste the invite link',
      'accept_invite': 'Accept invite',
      'invite_invalid': "That doesn't look like a GuardianX invite link",
      'invite_accepted': "You're now {name}'s guardian",
      'no_people_yet': 'No one yet. Accept an invite to start protecting someone.',
      'added_you_as': 'Added you as: {relation}',

      // Settings
      'settings_language': 'Language',
      'settings_safety': 'Safety setup',
      'settings_account': 'Account',
      'sign_out': 'Sign out',
      'sign_out_body': "You'll need to set your PINs again when you sign back in on this phone.",
      'delete_account': 'Delete account',
      'delete_account_body':
          "This permanently deletes your profile, contacts, settings and SOS history. This can't be undone.",
    },
    'hi': {
      // Common
      'continue': 'आगे बढ़ें',
      'continue_anyway': 'फिर भी आगे बढ़ें',
      'done': 'हो गया',
      'cancel': 'रद्द करें',
      'save': 'सेव करें',
      'saved': 'सेव हो गया',
      'skip': 'छोड़ें',
      'skip_for_now': 'अभी छोड़ें',
      'remove': 'हटाएँ',
      'delete': 'मिटाएँ',
      'allow': 'अनुमति दें',
      'allow_all': 'सभी की अनुमति दें',
      'open_settings': 'सेटिंग्स खोलें',
      'essential': 'ज़रूरी',
      'backup': 'बैकअप',
      'settings': 'सेटिंग्स',
      'retry': 'फिर से कोशिश करें',
      'step_of': 'चरण {n} / {total}',
      'name': 'नाम',
      'full_name': 'पूरा नाम',
      'email': 'ईमेल',
      'phone': 'फ़ोन नंबर',
      'password': 'पासवर्ड',
      'confirm_password': 'पासवर्ड दोबारा लिखें',
      'new_password': 'नया पासवर्ड',

      // Errors
      'err_required': 'यह भरना ज़रूरी है',
      'err_email': 'सही ईमेल पता लिखें',
      'err_password': 'कम से कम 8 अक्षर रखें',
      'err_password_match': 'पासवर्ड मेल नहीं खाते',
      'err_phone': 'सही फ़ोन नंबर लिखें',
      'err_code': 'ईमेल में आया पूरा कोड लिखें',
      'err_consent': 'आगे बढ़ने के लिए गोपनीयता शर्तें स्वीकार करें',
      'err_offline': 'इंटरनेट नहीं है। नेटवर्क जाँचें और फिर कोशिश करें।',
      'err_generic': 'कुछ गड़बड़ हुई। फिर कोशिश करें।',
      'err_duplicate': 'यह नंबर पहले से आपकी सूची में है',
      'err_invite_not_found': 'यह आमंत्रण मान्य नहीं है। नया आमंत्रण माँगें।',
      'err_own_invite': 'आप अपना ही आमंत्रण स्वीकार नहीं कर सकते।',
      'err_invite_used': 'यह आमंत्रण पहले ही किसी और ने स्वीकार कर लिया है।',
      'err_contact_limit': 'आप अधिकतम 5 मुख्य और 3 बैकअप संपर्क जोड़ सकते हैं।',
      'err_not_signed_in': 'कृपया फिर से साइन इन करें।',
      'already_registered': 'इस ईमेल से पहले से खाता है। लॉग इन करें।',
      'config_missing_title': 'ऐप सेट नहीं है',
      'config_missing_body':
          'Supabase कुंजियाँ नहीं मिलीं। SETUP.md के अनुसार ऐप को --dart-define-from-file=env.json के साथ चलाएँ।',

      // Welcome and role
      'welcome_tagline': 'एक टैप से आपके भरोसेमंद लोगों को आपकी लाइव लोकेशन के साथ अलर्ट मिलता है।',
      'privacy_title': 'आपकी गोपनीयता सबसे पहले',
      'privacy_body':
          'आपकी लोकेशन, रिकॉर्डिंग और मेडिकल जानकारी सिर्फ़ आपके चुने हुए गार्डियन के साथ, और सिर्फ़ आपात स्थिति में साझा होती है। आप कभी भी सब कुछ मिटा सकते हैं।',
      'get_started': 'शुरू करें',
      'have_account': 'मेरा पहले से खाता है',
      'role_title': 'आप GuardianX कैसे इस्तेमाल करेंगे?',
      'role_subtitle': 'जो आपके लिए सही हो, वह चुनें।',
      'role_protected': 'मुझे सुरक्षा चाहिए',
      'role_protected_desc': 'SOS अलर्ट भेजें, लाइव लोकेशन साझा करें और सबूत रिकॉर्ड करें।',
      'role_guardian': 'मैं गार्डियन हूँ',
      'role_guardian_desc': 'जिनकी आप रक्षा करते हैं, उन्हें मदद चाहिए तो अलर्ट पाएँ और लाइव देखें।',
      'role_both': 'दोनों',
      'role_both_desc': 'खुद सुरक्षित रहें और दूसरों का भी ध्यान रखें।',

      // Sign up, verify, login, reset
      'signup_title': 'अपना खाता बनाएँ',
      'consent_text':
          'मैं सहमत हूँ कि GuardianX मेरी सुरक्षा के लिए मेरी जानकारी रखे और उसे सिर्फ़ आपात स्थिति में मेरे गार्डियन के साथ साझा करे।',
      'create_account': 'खाता बनाएँ',
      'verify_title': 'अपना ईमेल सत्यापित करें',
      'verify_body': 'हमने {email} पर {n} अंकों का कोड भेजा है। उसे नीचे लिखें।',
      'verify': 'सत्यापित करें',
      'resend_code': 'कोड दोबारा भेजें',
      'resend_in': '{s} सेकंड में कोड दोबारा भेजें',
      'code_resent': 'नया कोड भेजा जा रहा है',
      'check_spam': 'नहीं मिला? स्पैम फ़ोल्डर देखें।',
      'login_title': 'फिर से स्वागत है',
      'login': 'लॉग इन करें',
      'forgot_password': 'पासवर्ड भूल गए?',
      'no_account': 'नया खाता बनाएँ',
      'email_not_confirmed': 'आपका ईमेल अभी सत्यापित नहीं है। हमने नया कोड भेजा है।',
      'reset_title': 'पासवर्ड बदलें',
      'reset_body': 'अपने खाते का ईमेल लिखें, हम 6 अंकों का कोड भेजेंगे।',
      'reset_enter_code': 'ईमेल में आया कोड लिखें और नया पासवर्ड चुनें।',
      'send_code': 'कोड भेजें',
      'reset_code_sent': '{email} पर कोड भेजा गया',
      'reset_password': 'पासवर्ड बदलें',
      'password_updated': 'पासवर्ड बदल गया',

      // Safety profile
      'safety_profile': 'सुरक्षा प्रोफ़ाइल',
      'profile_title': 'आपकी सुरक्षा प्रोफ़ाइल',
      'profile_subtitle':
          'SOS के दौरान गार्डियन और मदद करने वाले इसे देखते हैं। सिर्फ़ नाम और फ़ोन ज़रूरी हैं।',
      'profile_photo_hint': 'फ़ोटो जोड़ें ताकि गार्डियन आपको पहचान सकें',
      'blood_group': 'ब्लड ग्रुप',
      'allergies': 'एलर्जी',
      'allergies_hint': 'जैसे पेनिसिलिन या मूंगफली',
      'medical_notes': 'मेडिकल जानकारी',
      'medical_hint': 'बीमारी, दवाइयाँ, कुछ भी जो मदद करने वाले को पता होना चाहिए',
      'profile_privacy': 'सिर्फ़ आपके गार्डियन के साथ, और सिर्फ़ चालू SOS के दौरान साझा होता है।',
      'save_continue': 'सेव करें और आगे बढ़ें',
      'profile_incomplete': 'ब्लड ग्रुप और मेडिकल जानकारी जोड़ें',

      // Contacts
      'emergency_contacts': 'आपातकालीन संपर्क',
      'contacts_title': 'हम किसे अलर्ट करें?',
      'contacts_subtitle':
          'कम से कम एक मुख्य संपर्क जोड़ें। कोई जवाब न दे तो बैकअप संपर्कों को अलर्ट जाता है।',
      'contacts_empty': 'अभी कोई संपर्क नहीं',
      'pick_contact': 'फ़ोन के संपर्कों से चुनें',
      'enter_manually': 'नंबर लिखें',
      'contacts_info':
          'हर संपर्क को स्वीकार करने के लिए SMS आमंत्रण जाता है। जो पहले से सहमत होते हैं, वे आपात स्थिति में जल्दी मदद करते हैं।',
      'contacts_need_one': 'आगे बढ़ने के लिए कम से कम एक मुख्य संपर्क जोड़ें',
      'contacts_permission_denied': 'संपर्कों की अनुमति बंद है। आप नंबर लिख सकते हैं।',
      'contacts_limit': 'आप 5 मुख्य और 3 बैकअप संपर्क जोड़ सकते हैं',
      'contact_details': 'संपर्क की जानकारी',
      'choose_number': 'नंबर चुनें',
      'relation': 'रिश्ता',
      'rel_parent': 'माता/पिता',
      'rel_sibling': 'भाई/बहन',
      'rel_partner': 'जीवनसाथी',
      'rel_friend': 'दोस्त',
      'rel_relative': 'रिश्तेदार',
      'rel_other': 'अन्य',
      'backup_contact': 'बैकअप संपर्क',
      'backup_contact_desc': 'सिर्फ़ तब अलर्ट जाता है जब कोई मुख्य संपर्क जवाब न दे',
      'save_send_invite': 'सेव करें और आमंत्रण भेजें',
      'invite_sms':
          '{name} चाहते हैं कि आप उनके आपातकालीन संपर्क बनें। कभी कुछ हो, तो आपको लोकेशन लिंक के साथ संदेश मिल सकता है। यहाँ स्वीकार करें: {link}',
      'invite_sms_denied': 'SMS की अनुमति बंद है, इसलिए आमंत्रण नहीं गया। आप इसे बाद में भेज सकते हैं।',
      'invite_sent': '{name} को आमंत्रण भेजा गया',
      'invite_failed': '{name} को आमंत्रण नहीं भेजा जा सका',
      'status_accepted': 'स्वीकार किया',
      'status_declined': 'मना किया',
      'status_waiting': 'जवाब का इंतज़ार',
      'status_not_sent': 'आमंत्रण नहीं गया',
      'resend_invite': 'आमंत्रण फिर से भेजें',
      'make_primary': 'मुख्य संपर्क बनाएँ',
      'make_backup': 'बैकअप संपर्क बनाएँ',
      'remove_contact': 'संपर्क हटाएँ?',
      'remove_contact_body': '{name} को अब आपके अलर्ट नहीं मिलेंगे।',

      // Permissions
      'perm_title': 'SOS के लिए ज़रूरी अनुमतियाँ दें',
      'perm_subtitle':
          'हर अनुमति सिर्फ़ आपकी सुरक्षा के लिए इस्तेमाल होती है। आप इन्हें कभी भी सेटिंग्स में बदल सकते हैं।',
      'perm_location': 'लोकेशन',
      'perm_location_why': 'SOS के दौरान गार्डियन को आपकी सही लोकेशन भेजता है।',
      'perm_bg_location': 'हमेशा लोकेशन',
      'perm_bg_location_why':
          'स्क्रीन बंद होने पर भी ट्रैकिंग चालू रखता है। अगली स्क्रीन पर "हर समय अनुमति दें" चुनें।',
      'perm_camera': 'कैमरा',
      'perm_camera_why': 'गार्डियन के लिए लाइव वीडियो और सबूत की रिकॉर्डिंग।',
      'perm_mic': 'माइक्रोफ़ोन',
      'perm_mic_why': 'लाइव आवाज़ और ऑडियो सबूत।',
      'perm_sms': 'SMS',
      'perm_sms_why': 'आपके सिम से अपने-आप अलर्ट भेजता है, बिना इंटरनेट के भी।',
      'perm_notif': 'सूचनाएँ',
      'perm_notif_why': 'SOS की स्थिति और गार्डियन के आने की जानकारी दिखाता है।',
      'perm_battery': 'बैटरी पाबंदी हटाएँ',
      'perm_battery_why': 'Android को GuardianX बैकग्राउंड में बंद करने से रोकता है।',
      'perm_location_first': 'पहले लोकेशन की अनुमति दें',
      'perm_missing_title': 'SOS पूरी तरह काम नहीं करेगा',
      'perm_missing_body':
          'लोकेशन और SMS के बिना आपके गार्डियन को अलर्ट या लोकेशन शायद न मिले। फिर भी आगे बढ़ें?',
      'permissions_settings': 'अनुमतियाँ',

      // PINs
      'change_pins': 'PIN बदलें',
      'pin_current_title': 'अपना मौजूदा सुरक्षा PIN लिखें',
      'pin_safe_title': 'अपना सुरक्षा PIN बनाएँ',
      'pin_safe_body': 'SOS बंद करने के लिए यह 4 अंकों का PIN लगेगा, ताकि हमलावर इसे रद्द न कर सके।',
      'pin_confirm_title': 'दोबारा लिखें',
      'pin_confirm_safe_body': 'अपना सुरक्षा PIN पक्का करें।',
      'pin_confirm_duress_body': 'अपना दबाव PIN पक्का करें।',
      'pin_duress_title': 'दबाव PIN बनाएँ',
      'pin_duress_body': 'एक दूसरा, अलग PIN, जब कोई आपको SOS बंद करने पर मजबूर करे।',
      'pin_duress_how_title': 'दबाव PIN कैसे काम करता है',
      'pin_duress_how':
          'स्क्रीन पर लगेगा कि SOS बंद हो गया, लेकिन आपके गार्डियन को लोकेशन और यह चेतावनी मिलती रहेगी कि आपको रद्द करने पर मजबूर किया गया।',
      'pin_wrong': 'गलत PIN',
      'pin_weak': 'अंदाज़ा लगाना आसान है। एक जैसे या क्रम वाले अंक न रखें।',
      'pin_mismatch': 'PIN मेल नहीं खाए। फिर से शुरू करें।',
      'pin_same': 'दबाव PIN सुरक्षा PIN से अलग होना चाहिए',
      'pins_saved': 'PIN सेव हो गए',

      // Test alert
      'test_title': 'टेस्ट अलर्ट भेजें',
      'test_subtitle': 'जाँचें कि आपके संपर्कों को आपके संदेश मिलते हैं। हर संदेश पर TEST लिखा होगा।',
      'test_preview': 'संदेश की झलक',
      'test_sms':
          'GuardianX से TEST: {name} ने आपको आपातकालीन संपर्क बनाया है। यह सिर्फ़ टेस्ट है, कुछ करने की ज़रूरत नहीं। असली आपात स्थिति में आपको लाइव लिंक के साथ ऐसा ही संदेश मिलेगा।',
      'send_test': 'टेस्ट अलर्ट भेजें',
      'send_again': 'फिर से भेजें',
      'finish_setup': 'सेटअप पूरा करें',
      'skip_test_title': 'टेस्ट छोड़ें?',
      'skip_test_body': 'सिर्फ़ टेस्ट से पता चलता है कि आपके अलर्ट सच में संपर्कों तक पहुँचते हैं।',
      'test_cost_note': 'संदेश आपके सिम से जाते हैं। आपके प्लान के सामान्य SMS शुल्क लगेंगे।',
      'sms_permission_needed': 'टेस्ट भेजने के लिए SMS की अनुमति दें',
      'sms_sent': 'भेजा गया',
      'sms_failed': 'नहीं गया',
      'test_ask_contacts': 'अपने संपर्कों से पूछें कि संदेश मिला या नहीं।',

      // Home
      'hello': 'नमस्ते, {name}',
      'sos_hint': 'SOS दबाते ही आपके गार्डियन को अलर्ट जाता है।',
      'sos_not_active': 'अभी चालू नहीं',
      'contacts_accepted_count': '{total} में से {accepted} ने स्वीकार किया',
      'helplines': 'हेल्पलाइन',
      'helpline_112': 'आपातकाल',
      'helpline_1091': 'महिला (पुलिस)',
      'helpline_181': 'महिला (सहायता)',
      'people_i_protect': 'जिनकी मैं रक्षा करता/करती हूँ',

      // Guardian
      'guardian_title': 'गार्डियन',
      'guardian_info':
          'जिनकी आप रक्षा करते हैं, वे SOS भेजें तो आपको उनके वीडियो और लोकेशन के लाइव लिंक के साथ SMS मिलेगा।',
      'accept_invite_title': 'आमंत्रण मिला है?',
      'invite_code_label': 'आमंत्रण लिंक पेस्ट करें',
      'accept_invite': 'आमंत्रण स्वीकार करें',
      'invite_invalid': 'यह GuardianX आमंत्रण लिंक नहीं लगता',
      'invite_accepted': 'अब आप {name} के गार्डियन हैं',
      'no_people_yet': 'अभी कोई नहीं। किसी की रक्षा शुरू करने के लिए आमंत्रण स्वीकार करें।',
      'added_you_as': 'आपको जोड़ा: {relation}',

      // Settings
      'settings_language': 'भाषा',
      'settings_safety': 'सुरक्षा सेटअप',
      'settings_account': 'खाता',
      'sign_out': 'साइन आउट',
      'sign_out_body': 'इस फ़ोन पर दोबारा साइन इन करने पर आपको PIN फिर से बनाने होंगे।',
      'delete_account': 'खाता मिटाएँ',
      'delete_account_body':
          'इससे आपकी प्रोफ़ाइल, संपर्क, सेटिंग्स और SOS इतिहास हमेशा के लिए मिट जाएँगे। इसे वापस नहीं किया जा सकता।',
    },
    'pa': paAppStrings,
  };
}

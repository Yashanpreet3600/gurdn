import 'strings_pa.dart';

/// SOS screens, settings and the SOS text messages (Phase 1).
/// Kept separate from app_strings.dart so each phase adds its own file.
const Map<String, Map<String, String>> sosStrings = {
  'en': {
    // Levels
    'level_1_name': 'Level 1: Silent ping',
    'level_2_name': 'Level 2: Alert and tracking',
    'level_3_name': 'Level 3: Full SOS',
    'level_1_short': 'Ping',
    'level_2_short': 'Alert',
    'level_3_short': 'Full SOS',
    'level_1_desc': 'Texts your location once to your main contacts. No screen, no tracking.',
    'level_2_desc': 'Texts your contacts and keeps tracking you until you stop it with your PIN.',
    'level_3_desc': 'Everything in Level 2, plus live video and recording (coming in a later update).',

    // Button and countdown
    'sos_btn_open': 'SOS ACTIVE\nTap to open',
    'sos_btn_send': 'ARMED\nTap to send',
    'sos_hint_arming': 'Tap SOS 3 times quickly to arm it, then tap once more to send.',
    'sos_hint_direct': 'Tap SOS to send. You get {n} seconds to cancel.',
    'sos_running_hint': 'Your SOS is running. Tap the button to open it.',
    'sos_running_banner': 'SOS is active. Tap to open.',
    'sos_sending_in': 'Sending SOS in',
    'sos_send_now': 'Send now',
    'ping_sending': 'Sending your location…',
    'ping_sent': 'Silent location sent to {n} contacts',
    'ping_failed': "Couldn't send the SMS. Check that SMS permission is on.",

    // Active SOS
    'sos_no_contacts': 'No emergency contacts to alert. Add contacts in Settings.',
    'sos_active_title': 'SOS active',
    'sos_active_test': 'TEST SOS active',
    'sos_duress_running':
        'Running silently after the duress PIN. Your contacts were told you were forced to cancel.',
    'sos_escalated_title': 'No one has responded yet',
    'sos_escalated_body': 'Your backup contacts have been alerted too. If you can, call 112.',
    'sos_no_location_permission':
        'Location permission is off, so your contacts get no live location. Turn it on in Settings, then Permissions.',
    'sos_alerts': 'Alerts',
    'sos_location': 'Your location',
    'sos_finding_location': 'Finding your location…',
    'sos_location_value': 'Within {m} m, updated {time}',
    'sos_synced': 'Saved to the server',
    'sos_not_synced': 'Saved on this phone. Uploads when internet returns.',
    'hide_screen': 'Hide screen',
    'call_112': 'Call 112',
    'stop_sos': 'Stop SOS',
    'sos_leave_hint': 'You can leave this screen. The SOS keeps running until you stop it with your PIN.',
    'sms_not_yet': 'Not alerted',
    'sms_sending': 'Sending',

    // Stop and hidden screen
    'stop_sos_title': 'Enter your safety PIN',
    'stop_sos_body': 'The SOS stops only with your PIN.',
    'pin_locked': 'Too many wrong PINs. Try again in {s} s.',
    'sos_stopped': 'SOS stopped',
    'stop_sos_first': 'Stop the SOS first',
    'hidden_hint': 'SOS is still running.\nHold anywhere for 3 seconds to come back.',
    'notif_title': 'GuardianX',
    'notif_text': 'Running. Tap to open.',

    // Settings
    'sos_settings': 'SOS settings',
    'sos_default_level': 'Default level',
    'sos_messages': 'Alert messages',
    'sos_messages_hint':
        'Short messages cost less: each SMS part holds about 160 English or 70 Hindi characters.',
    'sos_countdown': 'Countdown before sending',
    'seconds_short': '{n} s',
    'minutes_short': '{n} min',
    'sos_arming': 'Tap 3 times to arm',
    'sos_arming_desc': 'Stops the SOS from going off by accident in a pocket or bag.',
    'sms_language': 'SMS language',
    'sms_language_hint':
        'English SMS fit more text per message. Hindi messages are split into more parts.',
    'escalation_after': 'Alert backup contacts after',
    'escalation_hint':
        'If no guardian opens your alert in this time, backup contacts are texted too.',
    'sos_saved_offline':
        "Couldn't reach the server. Saved on this phone for now; save again when you're online.",
    'test_sos_title': 'Run a test SOS?',
    'test_sos_body':
        "This runs a full Level 2 SOS. Every message is marked TEST, so your contacts know it isn't real. Stop it with your safety PIN.",
    'test_sos_start': 'Run a test SOS',

    // History
    'sos_history': 'SOS history',
    'sos_history_empty': 'No SOS yet.',
    'event_status_active': 'Active',
    'event_status_ended': 'Stopped',
    'event_status_cancelled': 'Cancelled',
    'event_status_duress': 'Duress PIN',

    // Invite without a web page
    'invite_sms_code':
        '{name} would like you to be an emergency contact. If anything ever happens, you may get a text with their location. Have the app? Accept with this code: {code}',

    // SOS text messages
    'sms_test_prefix': 'TEST - ',
    'sms_from': '- {name}, {time}',
    'sms_location': 'Location: {link} (within {m} m)',
    'sms_location_old': 'Last known location, {min} min old: {link} (within {m} m)',
    'sms_location_pending': 'Exact location follows in the next SMS.',
    'sms_battery': 'Battery: {b}%',
    'sms_track': 'Live: {link}',
    'sms_precise': '{name} exact location: {link} (within {m} m) at {time}',
    'sms_update': '{name} new location: {link} (within {m} m) at {time}',
    'sms_escalation':
        'URGENT: {name} sent an SOS {min} min ago and no one has responded yet. Please call them or 112.',
    'sms_duress':
        'WARNING: {name} was forced to cancel the SOS and may still be in danger. Please call 112.',
    'sms_low_battery': 'WARNING: {name} phone battery is at {b}% and may die soon. Last location below. Please call them or 112.',
    'sms_safe': '{name} is safe now. The SOS was stopped at {time}.',
  },
  'hi': {
    // Levels
    'level_1_name': 'लेवल 1: चुपचाप लोकेशन',
    'level_2_name': 'लेवल 2: अलर्ट और ट्रैकिंग',
    'level_3_name': 'लेवल 3: पूरा SOS',
    'level_1_short': 'लोकेशन',
    'level_2_short': 'अलर्ट',
    'level_3_short': 'पूरा SOS',
    'level_1_desc': 'आपकी लोकेशन एक बार मुख्य संपर्कों को SMS करता है। न स्क्रीन, न ट्रैकिंग।',
    'level_2_desc': 'आपके संपर्कों को SMS करता है और PIN से रोकने तक आपको ट्रैक करता रहता है।',
    'level_3_desc': 'लेवल 2 की सारी चीज़ें, साथ में लाइव वीडियो और रिकॉर्डिंग (अगले अपडेट में)।',

    // Button and countdown
    'sos_btn_open': 'SOS चालू\nखोलने के लिए टैप करें',
    'sos_btn_send': 'तैयार\nभेजने के लिए टैप करें',
    'sos_hint_arming': 'तैयार करने के लिए SOS को जल्दी-जल्दी 3 बार टैप करें, फिर भेजने के लिए एक बार और टैप करें।',
    'sos_hint_direct': 'भेजने के लिए SOS टैप करें। रद्द करने के लिए {n} सेकंड मिलेंगे।',
    'sos_running_hint': 'आपका SOS चल रहा है। खोलने के लिए बटन टैप करें।',
    'sos_running_banner': 'SOS चालू है। खोलने के लिए टैप करें।',
    'sos_sending_in': 'SOS इतने सेकंड में जाएगा',
    'sos_send_now': 'अभी भेजें',
    'ping_sending': 'आपकी लोकेशन भेजी जा रही है…',
    'ping_sent': '{n} संपर्कों को चुपचाप लोकेशन भेजी गई',
    'ping_failed': 'SMS नहीं जा सका। जाँचें कि SMS की अनुमति चालू है।',

    // Active SOS
    'sos_no_contacts': 'अलर्ट करने के लिए कोई आपातकालीन संपर्क नहीं। सेटिंग्स में संपर्क जोड़ें।',
    'sos_active_title': 'SOS चालू',
    'sos_active_test': 'टेस्ट SOS चालू',
    'sos_duress_running':
        'दबाव PIN के बाद चुपचाप चल रहा है। आपके संपर्कों को बताया गया कि आपको रद्द करने पर मजबूर किया गया।',
    'sos_escalated_title': 'अभी तक किसी ने जवाब नहीं दिया',
    'sos_escalated_body': 'आपके बैकअप संपर्कों को भी अलर्ट भेजा गया है। हो सके तो 112 पर कॉल करें।',
    'sos_no_location_permission':
        'लोकेशन की अनुमति बंद है, इसलिए संपर्कों को लाइव लोकेशन नहीं मिलेगी। सेटिंग्स में अनुमतियाँ खोलकर चालू करें।',
    'sos_alerts': 'अलर्ट',
    'sos_location': 'आपकी लोकेशन',
    'sos_finding_location': 'आपकी लोकेशन ढूँढी जा रही है…',
    'sos_location_value': '{m} मीटर के अंदर, {time} पर अपडेट',
    'sos_synced': 'सर्वर पर सेव हो गया',
    'sos_not_synced': 'इस फ़ोन पर सेव है। इंटरनेट आने पर अपलोड होगा।',
    'hide_screen': 'स्क्रीन छिपाएँ',
    'call_112': '112 पर कॉल करें',
    'stop_sos': 'SOS रोकें',
    'sos_leave_hint': 'आप यह स्क्रीन छोड़ सकते हैं। PIN से रोकने तक SOS चलता रहेगा।',
    'sms_not_yet': 'अलर्ट नहीं गया',
    'sms_sending': 'भेजा जा रहा है',

    // Stop and hidden screen
    'stop_sos_title': 'अपना सुरक्षा PIN लिखें',
    'stop_sos_body': 'SOS सिर्फ़ आपके PIN से रुकता है।',
    'pin_locked': 'बहुत बार गलत PIN। {s} सेकंड बाद फिर कोशिश करें।',
    'sos_stopped': 'SOS रुक गया',
    'stop_sos_first': 'पहले SOS रोकें',
    'hidden_hint': 'SOS अभी भी चल रहा है।\nवापस आने के लिए कहीं भी 3 सेकंड दबाकर रखें।',
    'notif_title': 'GuardianX',
    'notif_text': 'चल रहा है। खोलने के लिए टैप करें।',

    // Settings
    'sos_settings': 'SOS सेटिंग्स',
    'sos_default_level': 'डिफ़ॉल्ट लेवल',
    'sos_messages': 'अलर्ट संदेश',
    'sos_messages_hint': 'छोटे संदेश सस्ते पड़ते हैं: हर SMS भाग में लगभग 160 अंग्रेज़ी या 70 हिंदी अक्षर आते हैं।',
    'sos_countdown': 'भेजने से पहले उलटी गिनती',
    'seconds_short': '{n} से.',
    'minutes_short': '{n} मिनट',
    'sos_arming': 'तैयार करने के लिए 3 बार टैप',
    'sos_arming_desc': 'जेब या बैग में गलती से SOS जाने से रोकता है।',
    'sms_language': 'SMS की भाषा',
    'sms_language_hint': 'अंग्रेज़ी SMS में ज़्यादा शब्द आते हैं। हिंदी संदेश ज़्यादा भागों में बँटते हैं।',
    'escalation_after': 'इतने समय बाद बैकअप संपर्कों को अलर्ट करें',
    'escalation_hint': 'अगर इस समय में कोई गार्डियन आपका अलर्ट नहीं खोलता, तो बैकअप संपर्कों को भी SMS जाता है।',
    'sos_saved_offline': 'सर्वर तक नहीं पहुँच सके। अभी इस फ़ोन पर सेव है; ऑनलाइन होने पर फिर से सेव करें।',
    'test_sos_title': 'टेस्ट SOS चलाएँ?',
    'test_sos_body':
        'इससे पूरा लेवल 2 SOS चलेगा। हर संदेश पर TEST लिखा होगा, ताकि संपर्क जानें कि यह असली नहीं है। इसे अपने सुरक्षा PIN से रोकें।',
    'test_sos_start': 'टेस्ट SOS चलाएँ',

    // History
    'sos_history': 'SOS इतिहास',
    'sos_history_empty': 'अभी तक कोई SOS नहीं।',
    'event_status_active': 'चालू',
    'event_status_ended': 'रोका गया',
    'event_status_cancelled': 'रद्द',
    'event_status_duress': 'दबाव PIN',

    // Invite without a web page
    'invite_sms_code':
        '{name} चाहते हैं कि आप उनके आपातकालीन संपर्क बनें। कभी कुछ हो, तो आपको उनकी लोकेशन के साथ संदेश मिल सकता है। ऐप है? इस कोड से स्वीकार करें: {code}',

    // SOS text messages
    'sms_test_prefix': 'टेस्ट - ',
    'sms_from': '- {name}, {time}',
    'sms_location': 'लोकेशन: {link} ({m} मी. के अंदर)',
    'sms_location_old': 'आखिरी लोकेशन, {min} मिनट पुरानी: {link} ({m} मी. के अंदर)',
    'sms_location_pending': 'सही लोकेशन अगले SMS में आएगी।',
    'sms_battery': 'बैटरी: {b}%',
    'sms_track': 'लाइव: {link}',
    'sms_precise': '{name} की सही लोकेशन: {link} ({m} मी. के अंदर), {time}',
    'sms_update': '{name} की नई लोकेशन: {link} ({m} मी. के अंदर), {time}',
    'sms_escalation':
        'ज़रूरी: {name} ने {min} मिनट पहले SOS भेजा और अभी तक किसी ने जवाब नहीं दिया। कृपया उन्हें या 112 पर कॉल करें।',
    'sms_duress':
        'चेतावनी: {name} को SOS रद्द करने पर मजबूर किया गया, वे अभी भी खतरे में हो सकते हैं। कृपया 112 पर कॉल करें।',
    'sms_low_battery': 'चेतावनी: {name} के फ़ोन की बैटरी {b}% है और जल्द बंद हो सकती है। आख़िरी लोकेशन नीचे है। कृपया उन्हें या 112 को कॉल करें।',
    'sms_safe': '{name} अब सुरक्षित हैं। SOS {time} पर रोका गया।',
  },
  'pa': paSosStrings,
};

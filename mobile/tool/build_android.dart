import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final configFile = File('android/app/google-services.json');
  if (!configFile.existsSync()) {
    stderr.writeln('Missing android/app/google-services.json');
    exitCode = 1;
    return;
  }

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final project = config['project_info'] as Map<String, dynamic>;
  final clients = config['client'] as List<dynamic>;
  final client = clients.cast<Map<String, dynamic>>().firstWhere(
    (item) =>
        ((item['client_info'] as Map<String, dynamic>)['android_client_info']
            as Map<String, dynamic>)['package_name'] ==
        'com.gooddaykilotaxi.app',
  );
  final clientInfo = client['client_info'] as Map<String, dynamic>;
  final apiKeys = client['api_key'] as List<dynamic>;
  final apiKey =
      (apiKeys.first as Map<String, dynamic>)['current_key'] as String;

  final firebaseResources = File(
    'android/app/src/main/res/values/firebase.xml',
  );
  firebaseResources.parent.createSync(recursive: true);
  firebaseResources.writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="google_app_id" translatable="false">${clientInfo['mobilesdk_app_id']}</string>
    <string name="gcm_defaultSenderId" translatable="false">${project['project_number']}</string>
    <string name="project_id" translatable="false">${project['project_id']}</string>
    <string name="google_api_key" translatable="false">$apiKey</string>
</resources>
''');

  final process = await Process.start('flutter', [
    'build',
    'apk',
    '--release',
    '--dart-define=API_BASE_URL=https://taxi.saihtet.dev/api',
    '--dart-define=FIREBASE_API_KEY=$apiKey',
    '--dart-define=FIREBASE_APP_ID=${clientInfo['mobilesdk_app_id']}',
    '--dart-define=FIREBASE_MESSAGING_SENDER_ID=${project['project_number']}',
    '--dart-define=FIREBASE_PROJECT_ID=${project['project_id']}',
  ]);
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  exitCode = await process.exitCode;
}

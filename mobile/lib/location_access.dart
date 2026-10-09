import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api.dart';
import 'app_language.dart';
import 'app_theme.dart';

Future<Position> currentPositionWithRecovery(BuildContext context) async {
  final serviceError = AppLanguage.text(
    context,
    'Turn on location services to use your current location.',
  );
  final permissionError = AppLanguage.text(
    context,
    'Allow location access to use your current location.',
  );
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) {
      await _settingsDialog(
        context,
        title: 'Location services are off',
        message: 'Turn on Android location services so the app can use GPS.',
        action: 'Open location settings',
        onOpen: Geolocator.openLocationSettings,
      );
    }
    throw ApiException(serviceError);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    if (context.mounted) {
      await _settingsDialog(
        context,
        title: 'Location access needed',
        message:
            'Allow location access in Android settings to use GPS and go online.',
        action: 'Open app settings',
        onOpen: Geolocator.openAppSettings,
      );
    }
    throw ApiException(permissionError);
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

Future<bool> ensureBackgroundLocationAccess(BuildContext context) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.always) return true;
  if (permission != LocationPermission.whileInUse) return false;

  if (!context.mounted) return false;
  final continueToPermission = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.location_on_rounded, color: taxiBlue),
      title: Text(
        AppLanguage.text(context, 'Allow driver tracking in background'),
      ),
      content: Text(
        AppLanguage.text(
          context,
          'Choose Allow all the time so passengers can see the taxi when this app is minimized or the screen is locked.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(AppLanguage.text(context, 'Not now')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(AppLanguage.text(context, 'Continue')),
        ),
      ],
    ),
  );
  if (continueToPermission != true) return false;

  permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.always) return true;
  if (!context.mounted) return false;
  await _settingsDialog(
    context,
    title: 'Background location needed',
    message:
        'Open Permissions, choose Location, then select Allow all the time.',
    action: 'Open app settings',
    onOpen: Geolocator.openAppSettings,
  );

  return await Geolocator.checkPermission() == LocationPermission.always;
}

Future<void> _settingsDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  required Future<bool> Function() onOpen,
}) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.location_on_rounded, color: taxiBlue),
      title: Text(AppLanguage.text(context, title)),
      content: Text(AppLanguage.text(context, message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(AppLanguage.text(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(AppLanguage.text(context, action)),
        ),
      ],
    ),
  );
  if (open == true) await onOpen();
}

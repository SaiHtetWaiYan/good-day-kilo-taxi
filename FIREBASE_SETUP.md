# Firebase push notification setup

The app and Laravel API contain the complete Firebase Cloud Messaging integration. Delivery becomes active after adding one Firebase project and service account.

## Android app

1. Create a Firebase project.
2. Add an Android app with package name `com.gooddaykilotaxi.app`.
3. Download `google-services.json` and place it at `mobile/android/app/google-services.json`. The build helper generates Firebase's Android resources from this file so Firebase can initialize when Android starts the app to deliver a background notification.
4. In Firebase project settings, copy the Web API key, Android app ID, project number, and project ID.
5. Build the APK with the included helper, which reads the required non-secret Android values from `google-services.json`:

```bash
dart run tool/build_android.dart
```

The equivalent command is:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://taxi.saihtet.dev/api \
  --dart-define=FIREBASE_API_KEY=YOUR_WEB_API_KEY \
  --dart-define=FIREBASE_APP_ID=YOUR_ANDROID_APP_ID \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_PROJECT_NUMBER \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
```

The app initializes Firebase programmatically, asks for notification permission, registers its FCM token with Laravel, refreshes changed tokens, and displays foreground notifications on the `taxi_bookings` Android channel.

## Laravel server

1. In Firebase project settings, open **Service accounts** and create a private key.
2. Add these values to the production `.env`:

```dotenv
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-...@your-project-id.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

For production, the deployed app uses the safer file-based setting instead:

```dotenv
FIREBASE_CREDENTIALS=/var/www/good-day-kilo-taxi-api/storage/app/firebase-service-account.json
```

3. Clear cached configuration:

```bash
php artisan optimize:clear
php artisan optimize
```

Laravel sends through the FCM HTTP v1 API and removes invalid device tokens automatically.

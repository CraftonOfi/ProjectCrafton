Push Notifications (FCM) – Integration Guide
===========================================

This app is prepared to register device tokens and receive push notifications from the backend. To fully enable push notifications, follow these steps:

1) Add Firebase packages
------------------------

Temporarily removed to fix web build issues. Reintroduce compatible versions for your Flutter SDK:

- firebase_core: ^2.27.0
- firebase_messaging: ^14.7.10

Update your pubspec.yaml accordingly, then run flutter pub get.

2) Add Firebase project and apps
--------------------------------

- Create a Firebase project.
- Add Android app (use your applicationId from android/app/build.gradle). Download google-services.json and place it in android/app/.
- Add iOS app. Download GoogleService-Info.plist and add it to iOS Runner target.
- (Optional) Add a Web app, copy its config for web initialization.

3) Initialize Firebase in main.dart
-----------------------------------

At app startup, before runApp, initialize Firebase:

import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart'; // if using FlutterFire CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // if using FlutterFire CLI
  );
  // ... existing init
}

4) Request permissions and get FCM token
----------------------------------------

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart'; // optional for platform

final fcm = FirebaseMessaging.instance;
final settings = await fcm.requestPermission();
if (settings.authorizationStatus == AuthorizationStatus.authorized ||
    settings.authorizationStatus == AuthorizationStatus.provisional) {
  final token = await fcm.getToken();
  // Register token in backend
  ref.read(pushRegistrationServiceProvider).registerToken(
    token!,
    platform: defaultTargetPlatform.name.toLowerCase(),
  );
}

Also handle token refresh:

FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  ref.read(pushRegistrationServiceProvider).registerToken(newToken);
});

5) Handle foreground messages
-----------------------------

FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Show a local notification (e.g., via flutter_local_notifications)
  // or update in-app notifications provider.
});

6) Backend setup
----------------

- Set FCM_SERVER_KEY in backend .env with your Firebase project Server key (Legacy key) or wire HTTP v1 with a service account.
- The backend already supports token registration at:
  - POST /api/devices/register { token, platform? }
  - POST /api/devices/unregister { token }
  - POST /api/devices/test-push – sends a test push to your tokens
- Booking events trigger DB notifications, and if tokens exist, a push is attempted.

Notes
-----
- For iOS, ensure push capabilities are enabled and APNs key/certificate is configured in Firebase.
- For Android 13+, add POST_NOTIFICATIONS runtime permission handling.
- For Web, include the Firebase Web SDK configuration and a service worker (firebase-messaging-sw.js).

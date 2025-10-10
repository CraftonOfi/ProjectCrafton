import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

/// Servicio de registro de token de notificaciones push.
///
/// Nota: La app actualmente no incluye firebase_messaging en pubspec.
/// Cuando se reintroduzca, obtén el FCM token y llama a [registerToken].
class PushRegistrationService {
  final ApiService _api;
  PushRegistrationService(this._api);

  Future<void> registerToken(String token, {String? platform}) async {
    try {
      await _api.post('/devices/register', data: {
        'token': token,
        if (platform != null) 'platform': platform,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Register token failed: $e');
      }
    }
  }

  Future<void> unregisterToken(String token) async {
    try {
      await _api.post('/devices/unregister', data: {
        'token': token,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Unregister token failed: $e');
      }
    }
  }
}

final pushRegistrationServiceProvider =
    Provider<PushRegistrationService>((ref) {
  final api = ref.read(apiServiceProvider);
  return PushRegistrationService(api);
});

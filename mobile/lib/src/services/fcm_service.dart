import 'package:flutter/foundation.dart';

/// Abstracción para obtener el token FCM sin acoplarse a firebase_messaging.
/// Implementación actual: stub que devuelve null (para Web o cuando no se configuró FCM aún).
class FcmService {
  const FcmService();

  Future<String?> requestToken() async {
    // En web o entornos sin FCM configurado, devolvemos null.
    if (kIsWeb) return null;
    // En móviles, aquí iría la integración real con firebase_messaging.
    return null;
  }

  void listenTokenRefresh(void Function(String token) onRefresh) {
    // No-op en stub
  }
}

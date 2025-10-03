import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

// Estado de autenticación
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool clearError =
        false, // cuando true, se fuerza error = null ignorando "error" recibido
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      // Importante: antes se usaba `error ?? this.error` lo que impedía limpiar el error pasando null.
      // Ahora: si clearError es true => error = null. Si se pasa explícitamente un String (aunque vacío) se usa.
      // Si no se pasa nada y clearError es false => conserva el valor anterior.
      error: clearError ? null : (error ?? this.error),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  String toString() {
    return 'AuthState(user: $user, isLoading: $isLoading, error: $error, isAuthenticated: $isAuthenticated)';
  }
}

// Notifier para manejar la autenticación
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final Logger _logger = Logger();

  AuthNotifier(this._apiService) : super(const AuthState()) {
    _initializeAuth();
  }

  // Inicializar estado de autenticación al arrancar la app
  Future<void> _initializeAuth() async {
    state = state.copyWith(isLoading: true);

    try {
      final token = await StorageService.getToken();
      final user = await StorageService.getUser();

      if (token != null && user != null) {
        // Verificar que el token sigue siendo válido
        final isValid = await _verifyToken(token);
        if (isValid) {
          await StorageService.saveToken(token);
          _apiService.setToken(token);
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
          );
          _logger.i('Usuario autenticado automáticamente: ${user.email}');
        } else {
          await _clearAuthData();
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      _logger.e('Error inicializando autenticación: $e');
      await _clearAuthData();
      state = state.copyWith(
        isLoading: false,
        error: 'Error inicializando sesión',
      );
    }
  }

  // Verificar si el token sigue siendo válido
  Future<bool> _verifyToken(String token) async {
    try {
      final result = await _apiService.verifyToken(token);
      return result['valid'] == true;
    } catch (e) {
      _logger.w('Token inválido o expirado: $e');
      return false;
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiService.login(email: email, password: password);
      if (result['success'] == true) {
        final rawUser = result['user'] as Map<String, dynamic>?;
        if (rawUser == null) {
          state = state.copyWith(
              isLoading: false,
              error: 'Respuesta inválida del servidor (usuario nulo)');
          return false;
        }
        final normalizedUser = _normalizeUserJson(rawUser);
        final user = UserModel.fromJson(normalizedUser);
        final token = result['token'] as String?;
        if (token != null) {
          await StorageService.saveToken(token);
          _apiService.setToken(token);
        }
        await StorageService.saveUser(user);
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        _logger.i('Login exitoso: ${user.email}');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Credenciales inválidas',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error en login: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error de conexión',
      );
      return false;
    }
  }

  // Registro
  Future<bool> register(
    String email,
    String password,
    String name, {
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.register(
          email: email, password: password, name: name, phone: phone);
      if (result['success'] == true) {
        final rawUser = result['user'] as Map<String, dynamic>?;
        if (rawUser == null) {
          state = state.copyWith(
              isLoading: false,
              error: 'Respuesta inválida del servidor (usuario nulo)');
          return false;
        }
        final user = UserModel.fromJson(_normalizeUserJson(rawUser));
        final token = result['token'] as String?;
        if (token != null) await StorageService.saveToken(token);
        await StorageService.saveUser(user);
        _apiService.setToken(token);
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          error: null,
        );
        return true;
      } else {
        final message = result['message'] as String? ?? 'Error desconocido';
        state = state.copyWith(isLoading: false, error: message);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _clearAuthData();
      state = const AuthState();
      _logger.i('Logout exitoso');
    } catch (e) {
      _logger.e('Error en logout: $e');
    }
  }

  // Actualizar perfil
  Future<bool> updateProfile(String name, {String? phone}) async {
    if (!state.isAuthenticated || state.user == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiService.updateProfile(name: name, phone: phone);
      if (result['success'] == true) {
        final updatedUser =
            UserModel.fromJson(result['user'] as Map<String, dynamic>);
        await StorageService.saveUser(updatedUser);
        state = state.copyWith(
          user: updatedUser,
          isLoading: false,
        );
        _logger.i('Perfil actualizado exitosamente');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Error actualizando perfil',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error actualizando perfil: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error de conexión',
      );
      return false;
    }
  }

  // Cambiar contraseña
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    if (!state.isAuthenticated) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiService.changePassword(
          currentPassword: currentPassword, newPassword: newPassword);
      if (result['success'] == true) {
        state = state.copyWith(isLoading: false);
        _logger.i('Contraseña cambiada exitosamente');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Error cambiando contraseña',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error cambiando contraseña: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error de conexión',
      );
      return false;
    }
  }

  // Limpiar datos de autenticación
  Future<void> _clearAuthData() async {
    await StorageService.clearToken();
    await StorageService.clearUser();
    _apiService.clearToken(); // If not implemented, make this a no-op or remove
  }

  // Limpiar errores
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Refresh user data
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    try {
      final result = await _apiService.getProfile();
      if (result['success'] == true) {
        final rawUser = result['user'] as Map<String, dynamic>?;
        if (rawUser == null) return; // ignorar
        final updatedUser = UserModel.fromJson(_normalizeUserJson(rawUser));
        await StorageService.saveUser(updatedUser);
        state = state.copyWith(user: updatedUser);
        _logger.i('Datos de usuario actualizados');
      }
    } catch (e) {
      _logger.w('Error actualizando datos de usuario: $e');
    }
  }

  // Normaliza JSON de usuario cuando el backend no incluye algunos campos
  Map<String, dynamic> _normalizeUserJson(Map<String, dynamic> json) {
    final nowIso = DateTime.now().toIso8601String();
    return {
      ...json,
      // Backend login/register puede no incluir estos campos
      'isActive': json['isActive'] ?? true,
      'updatedAt': json['updatedAt'] ?? (json['createdAt'] ?? nowIso),
      'createdAt': json['createdAt'] ?? nowIso,
    };
  }
}

// Provider para el AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  // Usar instancia compartida para que el token se aplique a todas las peticiones
  final apiService = ref.read(apiServiceProvider);
  return AuthNotifier(apiService);
});

// Providers computados útiles
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role.isAdmin ?? false;
});

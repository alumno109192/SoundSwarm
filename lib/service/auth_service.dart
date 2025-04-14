import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // Inicializar sin scopes para reducir complejidad
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static GoogleSignInAccount? _currentUser;
  
  static GoogleSignInAccount? get currentUser => _currentUser;

  // Iniciar sesión con Google
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      // Primero, verificar si ya hay una sesión activa
      _currentUser = await _googleSignIn.signInSilently();
      
      // Si no hay sesión, intentar el flujo completo
      _currentUser ??= await _googleSignIn.signIn();
      
      if (_currentUser != null) {
        if (kDebugMode) {
          print('Usuario autenticado: ${_currentUser!.displayName}');
        }
      }
      
      return _currentUser;
    } catch (e) {
      if (kDebugMode) {
        print('Error en el inicio de sesión: $e');
      }
      return null;
    }
  }

  // Cerrar sesión
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      if (kDebugMode) {
        print('Sesión cerrada');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cerrar sesión: $e');
      }
    }
  }

  // Verificar si el usuario está conectado
  static bool isSignedIn() {
    return _currentUser != null;
  }
}

// Cliente HTTP autorizado para las solicitudes a la API
class GoogleAuthClient extends http.BaseClient {
  final String accessToken;
  final http.Client _client = http.Client();

  GoogleAuthClient(this.accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
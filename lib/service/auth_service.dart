import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/youtube.readonly',
    ],
  );

  static GoogleSignInAccount? _currentUser;
  static GoogleSignInAccount? get currentUser => _currentUser;

  // Iniciar sesión con Google/YouTube
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      _currentUser = account;
      
      if (account != null) {
        // Obtener autorización para acceder a YouTube
        await account.authentication;
        if (kDebugMode) {
          print('Usuario autenticado: ${account.displayName}');
        }
      }
      
      return account;
    } catch (e) {
      if (kDebugMode) {
        print('Error en el inicio de sesión: $e');
      }
      return null;
    }
  }

  // Cerrar sesión
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    if (kDebugMode) {
      print('Sesión cerrada');
    }
  }

  // Verificar si el usuario está conectado
  static bool isSignedIn() {
    return _currentUser != null;
  }

  // Obtener cliente autorizado para la API de YouTube
  static Future<YouTubeApi?> getYouTubeApi() async {
    if (_currentUser == null) return null;
    
    final auth = await _currentUser!.authentication;
    final client = GoogleAuthClient(auth.accessToken!);
    return YouTubeApi(client);
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
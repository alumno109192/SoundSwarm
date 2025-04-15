import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:screen_state/screen_state.dart';

class NotificationService {
  static final Screen _screen = Screen();
  static StreamSubscription<ScreenStateEvent>? _screenSubscription;
  static bool _isScreenLocked = false;
  static bool _initialized = false;

  // Callback que se llamará cuando cambie el estado de la pantalla
  static Function(bool isLocked)? onScreenStateChanged;

  static Future<void> initialize() async {
    try {
      // Verificar si el servicio ya está inicializado
      if (_initialized) return;
      
      // Solicitar permisos (solo necesario en algunas versiones de Android)
      // requestPermission method is not defined for Screen, removing this call
      
      // Suscribirse a cambios de estado de pantalla
      _screenSubscription = _screen.screenStateStream.listen(_onScreenStateEvent);
      
      _initialized = true;
      
      if (kDebugMode) {
        print('NotificationService inicializado correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar detector de pantalla: $e');
      }
      // No lanzar la excepción, simplemente registrarla
    }
  }

  static void _onScreenStateEvent(ScreenStateEvent event) {
    // Detectar cuando la pantalla se bloquea o desbloquea
    if (event == ScreenStateEvent.SCREEN_OFF) {
      _isScreenLocked = true;
      if (kDebugMode) {
        print('Pantalla bloqueada - Mostrando controles completos');
      }
    } else if (event == ScreenStateEvent.SCREEN_ON) {
      _isScreenLocked = false;
      if (kDebugMode) {
        print('Pantalla desbloqueada - Ocultando controles');
      }
    }

    // Notificar a los listeners del cambio
    if (onScreenStateChanged != null) {
      onScreenStateChanged!(_isScreenLocked);
    }
  }

  static bool get isScreenLocked => _isScreenLocked;

  static void dispose() {
    _screenSubscription?.cancel();
  }
}
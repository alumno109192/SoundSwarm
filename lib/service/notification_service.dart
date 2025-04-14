import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:screen_state/screen_state.dart';

class NotificationService {
  static final Screen _screen = Screen();
  static StreamSubscription<ScreenStateEvent>? _screenSubscription;
  static bool _isScreenLocked = false;

  // Callback que se llamará cuando cambie el estado de la pantalla
  static Function(bool isLocked)? onScreenStateChanged;

  static Future<void> initialize() async {
    try {
      // Solicitar permisos (solo necesario en algunas versiones de Android)
      // Nota: requestPermission no está definido para Screen. Verifique si se necesita un método alternativo o elimine esta línea si no es necesario.
      
      // Suscribirse a cambios de estado de pantalla
      _screenSubscription = _screen.screenStateStream.listen(_onScreenStateEvent);
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar detector de pantalla: $e');
      }
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
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

/// Configuración técnica basada en el ensayo; no valida precisión/frecuencia RNF.
Stream<Position> capturarGpsAndroid() {
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    throw StateError('Reactivar GPS con la app Android visible.');
  }
  return Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 10),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'VanFull: ubicación del viaje',
        notificationText: 'Compartiendo ubicación durante el viaje.',
        notificationChannelName: 'Ubicación del viaje',
        notificationIcon: AndroidResource(name: 'ic_gps_probe'),
        enableWakeLock: true,
        setOngoing: true,
      ),
    ),
  );
}

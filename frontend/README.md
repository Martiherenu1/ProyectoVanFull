# Vanfull — Frontend (Flutter Web + Mobile)

> ⚠️ Flutter/Dart no están instalados todavía en el entorno. Instalá el SDK y luego generá el proyecto
> **dentro de esta carpeta** (así se crean android/, ios/, web/ sobre la estructura propuesta).

## 1. Instalar Flutter

- Descargar el SDK: https://docs.flutter.dev/get-started/install/windows
- Verificar: `flutter doctor`

## 2. Crear el proyecto en esta carpeta

```bash
cd frontend
flutter create . --org com.vanfull --platforms=android,ios,web
```

## 3. Estructura propuesta de `lib/` (arquitectura por capas)

```
lib/
├── main.dart
├── core/            # config, tema, cliente HTTP (dio), constantes
├── models/          # DTOs que reflejan los schemas del backend
├── services/        # llamadas a la API FastAPI (auth, reservas, pagos, gps...)
├── providers/       # estado (Provider o Riverpod)
├── screens/         # pantallas (login, home, reservas, mapa, chatbot...)
└── widgets/         # componentes reutilizables
```

## 4. Paquetes sugeridos (agregar a pubspec.yaml)

- `dio` — cliente HTTP hacia la API
- `flutter_riverpod` o `provider` — manejo de estado
- `google_maps_flutter` (+ `google_maps_flutter_web`) — mapas y GPS (RF-021/022)
- `qr_flutter` / `mobile_scanner` — QR de abordaje (RF-014)
- `flutter_secure_storage` — token JWT (RF-045)

## 5. Conexión al backend

La API corre en `http://localhost:8000` (ver `docker-compose.yml`). Para Flutter Web en desarrollo,
apuntá el cliente HTTP a esa URL; el backend ya tiene CORS habilitado.

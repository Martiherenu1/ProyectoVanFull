# VanFull — Frontend (Flutter Web + Mobile)

App única para los tres roles (pasajero, chofer, administración). El rol lo define la cuenta con la que se
inicia sesión; cada rol tiene su tema y su densidad (48 / 64 / 36 px, ver `08-Brief-de-Diseno-UI.md`).

## Correr la app

Con el backend levantado (README raíz, «Puesta en marcha»):

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
```

- `API_BASE_URL` incluye el prefijo `/api`. Por defecto es `http://localhost:8000/api`. En el emulador de
  Android el host es `10.0.2.2`: `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`.
- Cuentas de prueba: `backend/db/seed/README.md`. El seed no trae viajes: crearlos con `POST /api/viajes` como
  administrador (o con el seed de la demo cuando esté integrado).
- Pruebas y análisis (los mismos que corre la CI): `flutter analyze` y `flutter test`.

## Estructura de `lib/`

```
lib/
├── main.dart            # arma el cliente HTTP, la sesión y la entrada por rol
├── core/
│   ├── api/             # ApiClient (HttpApiClient), ApiException y los adaptadores por área (AuthApi, PasajeroApi)
│   ├── session/         # Sesion, SesionController (en memoria) y SesionApp (login o entrada del rol)
│   ├── navigation/      # RoleRouter y AppRole
│   ├── theme/, format/  # tema por rol, tipografía, fechas e importes
├── models/              # lecturas de los schemas del backend, por área
└── screens/             # una carpeta por área: comun, pasajero, chofer
```

## Cómo se conecta una pantalla

Las pantallas **no crean clientes HTTP ni guardan la sesión**: reciben funciones (`typedef`) que las conectan con
la API. El adaptador de cada área (`core/api/*_api.dart`) implementa esas funciones sobre `ApiClient`: un 400 o
409 de una operación sobre reservas se lanza como `ReservaRechazada` y un 401 de login como
`CredencialesInvalidas`. Así las pantallas se prueban sin red y el backend sigue siendo la autoridad de las reglas.

## Pendiente

- La sesión vive solo en memoria: al cerrar la app hay que volver a ingresar (el token no se persiste).
- Chofer y administración todavía entran por la portada temporal de `RoleRouter`.
- GPS (`geolocator`, permisos de Android), QR de abordaje y mapas no están integrados.
- Las fuentes se descargan de Google Fonts en ejecución.

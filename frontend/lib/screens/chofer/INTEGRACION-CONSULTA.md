# Integración de consulta Chofer — entrega parcial de #123

## Interfaz para el contenedor común

```dart
ChoferShell(
  key: identidadDeSesion, // Key no basada en el texto del token.
  cargarViajes: cargarViajes, // Future<List<ViajeResumen>> Function(DateTime)
  cargarDetalle: cargarDetalle, // Future<OperacionAsignada?> Function(int)
  onSalir: salir, // VoidCallback
  fechaInicial: fechaInicial, // DateTime?, solo inicializa la selección.
)
```

El ejemplo describe la interfaz; no implementa composición ni sesión.

- Conservar las mismas funciones de carga mientras las fuentes no cambien; no
  crear closures nuevas en cada build. El shell pasa esas funciones directamente
  a las pantallas. Una reconstrucción con fuentes iguales no recarga consultas.
- Un reemplazo explícito de fuente se comunica a las rutas existentes; las
  pantallas invalidan respuestas anteriores. No equivale a cambiar de cuenta.
- Al cambiar de sesión, desmontar el shell o cambiar su key, para retirar también
  fecha, rutas y datos anteriores. Una fuente no autentica ni valida roles aquí.
- La fecha inicial es el día local si se omite. La selección se envía explícita;
  no representa la fecha por defecto del servidor. Volver del detalle conserva
  la selección y el listado, sin una recarga automática.
- La selección entrega el ID al detalle. `null` de cargarDetalle significa no
  disponible. Otros fallos conservan error genérico y reintento explícito.
- `onSalir` está disponible en listado y detalle, incluso durante carga. Solo
  notifica al propietario: este debe resolver la salida y retirar el componente.

## Límites y responsables comunicados por el usuario el 24/10/2026

- Facundo: composición, inyección estable, transporte y router comunes.
- Martiniano: autenticación, sesión, token y roles.
- Martín: listado, detalle, shell y adaptadores de Chofer.

Las fuentes externas deben resolver/notificar 401 y 403 al mecanismo común antes
de propagar el fallo a las pantallas. No hay un callback propio de autorización
en el shell: ni borra tokens, ni decide si corresponde salir o denegar acceso.
El contenedor común necesita acordar el tratamiento diferenciado y proteger una
sesión nueva de errores tardíos de la anterior. Esta entrega no fija esa política.

El contenedor común es propietario del cliente/transporte y de su cierre. El
shell y los adaptadores reciben dependencias prestadas: no crean ni cierran
clientes. Tampoco hacen login, reintentos HTTP automáticos o llamadas de logout.

## Dependencias y verificación

- Listado: reutilizar ViajesChoferApi existente al conectar HTTP.
- Detalle: PR #113 sigue abierta al verificar el 24/10/2026, HEAD e4ac0ac.
  No se copia su implementación; la conexión HTTP espera esa integración.
  No es una dependencia para publicar o probar este shell con fuentes inyectables.
- Las pruebas de este componente usan fuentes simuladas. No acreditan HTTP real,
  dataset, cuentas, dispositivo ni circuito autenticado.
- Sin acciones de inicio/finalización, control de ubicación ni GPS.
- Entrega parcial publicada en PR #128, sin merge; no cierra #123 ni #64.
  La suite completa anterior fue interrumpida
  después de 233 aprobadas y no acredita aprobación completa.

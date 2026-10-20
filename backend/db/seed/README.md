# Datos de prueba (seed)

Un solo conjunto de datos para desarrollo, pruebas y mocks de Flutter (CONTRIBUTING §2). Cada archivo
`.csv` es una tabla, con las columnas de `backend/db/schema.sql` y los ids explícitos para que las FK
entre archivos se lean a simple vista.

## Cómo cargarlo

Con la base levantada y migrada (`docker compose up -d db` y `alembic upgrade head`), desde la raíz
del repo:

```bash
docker compose run --rm backend python -m db.seed.cargar
```

Si ya hay datos, no carga nada y lo avisa. Con `--reiniciar` vacía las tablas del seed **y todo lo que
dependa de ellas** (`TRUNCATE ... CASCADE`) y vuelve a cargar:

```bash
docker compose run --rm backend python -m db.seed.cargar --reiniciar
```

La carga es una sola transacción: si algo falla, no queda nada a medias. `tests/test_seed.py` la
verifica, incluido que se pueda iniciar sesión con cada cuenta.

## Qué hay

| Archivo | Contenido |
|---|---|
| `persona`, `pasajero`, `cliente`, `cliente_individual` | 4 personas: 2 pasajeros (con su cliente individual), 1 chofer y 1 administrador |
| `cuenta_corriente` | Una cuenta corriente para cada uno de los 2 clientes individuales |
| `cuenta_acceso`, `cuenta_rol` | Una cuenta por persona. Roles: `pasajero` ×2, `chofer`, `administrador` |
| `servicio` | Un servicio universitario y uno laboral |
| `recorrido`, `parada`, `parada_recorrido` | Un recorrido con 3 paradas (nombres y sin coordenadas: son de prueba) |
| `contrasenas-de-prueba.csv` | Contraseña de cada cuenta. **No es una tabla**: el cargador la hashea con bcrypt y la guarda en `cuenta_acceso.hash_contrasena` |

Cuentas: `pasajero1@vanfull.test`, `pasajero2@vanfull.test`, `chofer1@vanfull.test` y
`admin1@vanfull.test`. Las contraseñas están en `contrasenas-de-prueba.csv`. Los datos son ficticios
(DNI que empiezan con 9, dominio `.test`).

## Qué NO hay, y por qué

El REPARTO dice que cada dueño agrega los datos de sus tablas, por PR a esta carpeta. Faltan:

| Tabla | De quién | Nota |
|---|---|---|
| `chofer`, `vehiculo`, `viaje` (alta) | Facundo | La cuenta `chofer1` existe, pero todavía no tiene fila en `chofer`: se agrega con el seed de esa área |
| `posicion_gps`, `abordaje`, `ausencia`, `nomina_pasajeros`, `integrante_nomina` | Martín | El escenario de la demo cruzada también es suyo |
| `pago`, `movimiento_cuenta`, `comprobante`, `abono_mensual`, `periodo_abono*` | Facundo | |
| `tarifa`, `contratacion`, `reserva`, `registro_lista_espera` | Martiniano | No se siembran a propósito: dependen de los pendientes #7 (respaldo de la reserva) y #9 (parámetros de tarifa), y cargarlas ahora sería inventar esa regla |

Para sumar tus tablas: agregá el `.csv` y su nombre en `ORDEN` (`cargar.py`), después de las tablas que
referencia por FK. `tests/test_seed.py` falla si un archivo y `ORDEN` no coinciden.

## Cuidado: el repositorio es público

Las contraseñas de `contrasenas-de-prueba.csv` las puede leer cualquiera. Por eso el cargador **se
niega a correr contra una base que no sea local** (`localhost`, `127.0.0.1` o `db`).

Para sembrar la base de la demo (Neon), usar un archivo de contraseñas propio, **fuera del repo**:

```bash
python -m db.seed.cargar --contrasenas /ruta/propia.csv --permitir-base-remota
```

## Detalles que conviene saber

- `cuenta_rol.csv` usa ids de `rol_acceso`, que fija la migración inicial en este orden: pasajero,
  chofer, administrador, dueno, representante_corporativo. El cargador lo verifica y se detiene si no
  coincide.
- Las PK son `GENERATED ALWAYS`; el cargador pide `OVERRIDING SYSTEM VALUE` para fijar los ids y
  reajusta las secuencias después, para que el próximo `INSERT` no choque.
- Un valor vacío en un CSV es `NULL`.

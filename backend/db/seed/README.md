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
| `persona`, `pasajero`, `cliente`, `cliente_individual` | 5 personas: 2 pasajeros (con su cliente individual), 2 choferes y 1 administrador |
| `chofer` | Las personas 3 y 5. La 3 tiene la cuenta `chofer1@vanfull.test`; la 5 ("Chofer Dos") **no tiene cuenta de acceso**: existe solo para probar la reasignación de CU-018. `chofer` usa `id_persona` como PK/FK; no tiene otro identificador |
| `cuenta_corriente` | Una cuenta corriente para cada uno de los 2 clientes individuales |
| `cuenta_acceso`, `cuenta_rol` | Una cuenta por persona. Roles: `pasajero` ×2, `chofer`, `administrador` |
| `servicio` | Un servicio universitario y uno laboral |
| `recorrido`, `parada`, `parada_recorrido` | Un recorrido con 3 paradas (nombres y sin coordenadas: son de prueba) |
| `vehiculo` | Vehículos 1 y 2, patentes sintéticas `VF029AA` y `VF030AA`, capacidad 20 cada uno (el 2 es para probar la reasignación) |
| `viaje` | Viajes 1 a 3 del 30/10/2026 sobre servicio y recorrido 1; horarios 07:30, 12:30 y 18:00, capacidad planificada 18 |
| `contrasenas-de-prueba.csv` | Contraseña de cada cuenta. **No es una tabla**: el cargador la hashea con bcrypt y la guarda en `cuenta_acceso.hash_contrasena` |

Cuentas: `pasajero1@vanfull.test`, `pasajero2@vanfull.test`, `chofer1@vanfull.test` y
`admin1@vanfull.test`. Las contraseñas están en `contrasenas-de-prueba.csv`. Los datos son ficticios
(DNI que empiezan con 9, dominio `.test`).

## Qué NO hay, y por qué

El REPARTO dice que cada dueño agrega los datos de sus tablas, por PR a esta carpeta. Faltan:

| Tabla | De quién | Nota |
|---|---|---|
| `posicion_gps`, `abordaje`, `ausencia`, `nomina_pasajeros`, `integrante_nomina` | Martín | El escenario de la demo cruzada también es suyo |
| `pago`, `movimiento_cuenta`, `comprobante`, `abono_mensual`, `periodo_abono*` | Facundo | |
| `tarifa`, `contratacion`, `reserva`, `registro_lista_espera` | Martiniano | No se siembran a propósito: dependen de los pendientes #7 (respaldo de la reserva) y #9 (parámetros de tarifa), y cargarlas ahora sería inventar esa regla |

Para sumar tus tablas: agregá el `.csv` y su nombre en `ORDEN` (`cargar.py`), después de las tablas que
referencia por FK. `tests/test_seed.py` falla si un archivo y `ORDEN` no coinciden.

### Escenarios administrativos propuestos para la demo

Estos datos son una **propuesta de prueba de Facundo**, pendiente de coordinación con Martín y
Martiniano. Los tres viajes están `programado`; ADJ-03 permite planificarlos incompletos, pero impide
iniciarlos mientras falte el chofer o el vehículo.

| Viaje | Horario | Chofer | Vehículo | Escenario |
|---|---|---|---|---|
| 1 | 07:30 | Persona 3 | Vehículo 1 | Completamente asignado |
| 2 | 12:30 | `NULL` | Vehículo 1 | Sin chofer |
| 3 | 18:00 | Persona 3 | `NULL` | Sin vehículo |

Martín puede reutilizar los viajes 1 y 3 en CU-029, porque ambos están asignados a la persona 3. Los
datos de reservas y contrataciones de Martiniano, y los abordajes, ausencias, posiciones y nóminas de
Martín, no forman parte de este seed administrativo.

## Cuidado: el repositorio es público

Las contraseñas de `contrasenas-de-prueba.csv` las puede leer cualquiera. Por eso el cargador **se
niega a correr contra una base que no sea local** (`localhost`, `127.0.0.1` o `db`).

Para sembrar la base de la demo (Neon) hacen falta las dos cosas: `--permitir-base-remota` y
`--contrasenas` con un archivo **fuera del repo**. La bandera sola no alcanza: con el archivo del repo, el
cargador se niega igual. El archivo se genera con contraseñas aleatorias, que no se imprimen:

```bash
python -m db.seed.generar_contrasenas /ruta/fuera/del/repo/contrasenas-demo.csv
python -m db.seed.cargar --permitir-base-remota --contrasenas /ruta/fuera/del/repo/contrasenas-demo.csv
```

El comando completo, con Docker y sin escribir la cadena de Neon en ningún archivo, está en
[`DESPLIEGUE.md`](../../../DESPLIEGUE.md).

## Detalles que conviene saber

- `cuenta_rol.csv` usa ids de `rol_acceso`, que fija la migración inicial en este orden: pasajero,
  chofer, administrador, dueno, representante_corporativo. El cargador lo verifica y se detiene si no
  coincide.
- Las PK son `GENERATED ALWAYS`; el cargador pide `OVERRIDING SYSTEM VALUE` para fijar los ids y
  reajusta las secuencias después, para que el próximo `INSERT` no choque.
- Un valor vacío en un CSV es `NULL`.

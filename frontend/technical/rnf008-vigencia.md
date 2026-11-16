# RNF-008 — candidata Flutter de vigencia contractual / #293

Fecha: 16/11/2026. Base exacta: implementación backend #292,
`8d22318d7e2f531ff81dafbdd6a30904ca9fdf51`, dependiente del contrato #272.

## Alcance y procedencia

RNF-008 conserva la frontera estricta de >30 segundos. El contrato aditivo de #272
aporta S UTC y no-store; #292 emite ese dato junto con T y su booleano.
Esta candidata implementa el diseño revisable descrito en el análisis de #39.
No convierte sus hipótesis técnicas en reglas de VanFull ni cierra #39.

La interfaz presenta, sin edad exacta:

| Evidencia | Mensaje |
| --- | --- |
| Servidor true o cota mínima válida >30 s | Información desactualizada |
| Intervalo que cruza 30 s, incluida [29,31] | Vigencia no confirmada |
| Metadato/transporte/ancla no verificables | Antigüedad no verificable |
| Intervalo completo ≤30 s | Sin marca de desactualización en la última consulta |

Permanece el aviso de captura física no verificada. Errores GET aparecen por separado,
sin afirmar que el chofer perdió conexión. ETA y recepción GPS no cambian.

## Referencia y aislamiento

- RTT y transcurrido se miden con Stopwatch, nunca DateTime.now. Referencia:
  A=S−T, cotas [A+d,A+RTT+d]. Se exige S UTC coherente con T/booleano,
  respuesta con Cache-Control:no-store y Age ausente o cero.
- Extensión **aditiva y compartida** ApiClientConMetadatos: las operaciones existentes
  get/post/patch conservan sus firmas, token y manejo del 401. Requiere revisión
  de Facundo/Martiniano antes de integrar. Clientes sin la capacidad siguen funcionando
  con incertidumbre, sin inventar una referencia. El request solicita no-cache.
- Cada consulta conserva la generación/fuente/sesión existente. P=(viaje,T,lat,lon).
  Igual T con otras coordenadas se rechaza; T anterior no reemplaza P. Mismas coordenadas
  con T posterior son P nueva. No hay persistencia ni transferencia entre cuentas.
- Para la misma P, false, S repetido o pérdida del ancla no borran una marca acreditada.
  Un S repetido no reinicia el transcurrido. S decreciente o reloj monotónico inválido
  impiden nuevos cálculos. Se comprueba el ancla anterior antes de sustituirla.
- Un timer visual de un segundo reevalúa aunque haya GET pendiente; el polling conserva
  diez segundos y no solapa consultas. La cadencia visual es técnica, no otro requisito.
- Cambio de viaje/fuente/alcance y pérdida de acceso retiran datos y referencia.
  Pausa/reanudación invalidan el ancla por falta de continuidad acreditada; una consulta
  que cruzó ese cambio no la restaura. El servidor true sigue siendo evidencia.

## Pruebas y límites

Casos nuevos separados de los diagnósticos originales: 29/30/31, RTT [29,31], paso del
tiempo con GET pendiente, S repetido/decreciente, booleano incoherente, falta de S/header,
Age reutilizado, retroceso monotónico, ciclo de vida, marca persistente y nueva P.
Se cubren además 401 tardío/token saliente, 401/403/404, cambio de viaje, coordenadas
incoherentes y compatibilidad del parser. Revisar también la suite Flutter existente.

Formato Dart y whitespace revisados. **Sin resultado de analyze/test local**: la revisión
automática bloqueó Flutter al detectar un acceso inesperado a 169.254.169.254 (metadatos
del entorno). No se eludió el bloqueo. Se usará CI aislada y se registrará por HEAD;
ni las 79 backend locales ni la CI de #292 se atribuyen a esta entrega Flutter.

Los dos diagnósticos originales y sus históricos permanecen fuera de esta rama,
sin sobrescribir aserciones, skips, exclusiones o resultados. [29,31] exige incertidumbre
en esta aceptación nueva: **no satisface la antigua aserción de desactualización exacta**.
El caso de envejecimiento dispone ahora de una referencia para probarse por separado.
No se declara cerrado ninguno de los diagnósticos originales sin su contraste explícito.

Pendientes para aceptación integral: revisión de pantalla/equipo; coherencia de reloj
servidor, intermediarios y respuesta fresca en el despliegue real; ensayo Web/Android
con referencia, demora, cierre y sesión identificados. El header no prueba por sí solo
ninguna de esas garantías. Sin cambios de timestamp, modelo, migraciones o datos.

## Ensayo posterior autorizado

1. Identificar SHA backend con S/header emitidos y SHA Web/APK con esta pantalla.
2. Verificar en una consulta fresca el metadato/no-store, sin exportar bearer ni HAR.
3. Con viaje autorizado, observar una posición conocida y detener nuevos envíos;
   comprobar transición visible y que el mapa no se presenta como ubicación actual.
4. Repetir con GET demorado/pendiente, cambio de sesión y viaje finalizado.
5. Registrar horas, versiones y resultados sanitizados; no atribuir edad física al T.

Este procedimiento no autoriza iniciar/finalizar viajes, despliegues o cambios de base.

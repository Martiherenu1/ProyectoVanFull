# Recursos técnicos — Vanfull

## Identificadores de modelos (OpenRouter)
- Principal: `minimax/minimax-m3:free`
- Fallback: `nvidia/nemotron-3-super-120b-a12b:free`
- Estrategia: endpoints `:free` para la fase académica, con fallback automático. Aceptar rate limiting
  como restricción de laboratorio. Reevaluar proveedor/costo/SLA en una eventual producción.

## Tools de AG-01 (contrato a implementar en FastAPI)
| Tool | Finalidad | Control |
|---|---|---|
| `consultar_disponibilidad()` | cupos por fecha/destino/sentido | dato del backend, no inventa |
| `consultar_horarios()` | horarios vigentes | fuente única: backend |
| `consultar_recorridos()` / `consultar_paradas()` | recorrido y paradas | config operativa vigente |
| `consultar_tarifa()` | tarifa por tipo de cliente y modalidad | no calcula importes fuera de reglas |
| `consultar_estado_pago()` / `consultar_deuda()` | estado del usuario autenticado | no modifica pagos |
| `consultar_reserva()` | reserva propia/autorizada | backend valida pertenencia |
| `crear_reserva()` | crear reserva | FastAPI valida cupo/reglas/datos |
| `cancelar_reserva()` | cancelar | FastAPI valida titularidad/plazo |
| `consultar_estado_viaje()` | estado operativo del viaje | realtime o backend |
| `consultar_ubicacion_vehiculo()` | ubicación del servicio | sólo usuarios vinculados |
| `derivar_humano()` | escalar a persona | ante pedido o si no resuelve seguro |

## Referencias oficiales (consultadas 27/08/2026 — verificar vigencia)
- OpenAI GPT-5.6 in ChatGPT: https://help.openai.com/en/articles/20001354-gpt-5-6-in-chatgpt
- OpenAI ChatGPT Work and Codex: https://help.openai.com/en/articles/20001275
- OpenAI Codex: https://openai.com/codex/
- Anthropic Claude Opus 4.8: https://www.anthropic.com/news/claude-opus-4-8
- Anthropic Claude Code: https://docs.anthropic.com/en/docs/claude-code/getting-started
- OpenRouter MiniMax M3 Free: https://openrouter.ai/minimax/minimax-m3:free
- OpenRouter Nemotron 3 Super Free: https://openrouter.ai/nvidia/nemotron-3-super-120b-a12b:free
- FastAPI Features / OpenAPI: https://fastapi.tiangolo.com/features/
- Flutter Web support: https://docs.flutter.dev/platform-integration/web
- Google Maps Routes — waypoint optimization: https://developers.google.com/maps/documentation/routes/opt-way
- Google Maps Routes — traffic: https://developers.google.com/maps/documentation/routes/config_trade_offs
- Google Maps — pricing: https://developers.google.com/maps/billing-and-pricing/pricing
- Mercado Pago — test accounts: https://www.mercadopago.com.ar/developers/en/docs/your-integrations/test/accounts
- Mercado Pago — credentials: https://www.mercadopago.com.ar/developers/es/docs/credentials
- Mercado Pago — webhooks: https://www.mercadopago.com.ar/developers/en/docs/your-integrations/notifications/webhooks
- Meta — WhatsApp Cloud API: https://developers.facebook.com/docs/whatsapp/cloud-api/

## Herramientas de IA que usa el equipo para desarrollar (no confundir con la IA del producto)
- Razonamiento/diseño: GPT-5.6 (ChatGPT), Claude Opus 4.8.
- Agentes de trabajo/documentación: ChatGPT Work.
- Agentes de programación: Codex, Claude Code.
- Gobernanza: revisión humana obligatoria antes de convertir sugerencia de IA en requisito/regla/código mergeado.

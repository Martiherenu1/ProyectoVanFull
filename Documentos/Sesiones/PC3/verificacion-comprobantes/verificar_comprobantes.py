#!/usr/bin/env python3
"""Verifica «Mis comprobantes» (CU-035, #295 y #297) contra una API de VanFull.

Solo biblioteca estandar. Las contrasenas se piden con getpass: nunca van por argumento, por chat ni a un
archivo, y el script no imprime tokens ni contrasenas.

Por defecto es SOLO LECTURA (login y GET). Con --escribir, ademas, y despues de que escribas ESCRIBIR,
crea UN pago de prueba y lo confirma, que es la unica forma de que nazca un recibo:

  1. el pasajero registra un pago           POST /pagos                       -> queda PENDIENTE
  2. administracion lo confirma             POST /pagos/{id}/confirmacion     -> nace el RECIBO

Eso ESCRIBE en la base: una fila en `pago`, un `comprobante` RECIBO, un `movimiento_cuenta` ACREEDOR y dos
`evento_operativo`. La API no tiene como borrarlos; solo se van re-sembrando con --reiniciar. Cambia el
saldo del pasajero. Se usa TRANSFERENCIA a proposito: EFECTIVO esta pendiente (#84, RN-011: el 15 %), y
MERCADO_PAGO solo lo confirma el proveedor.

Uso (desde cualquier carpeta):
  python verificar_comprobantes.py                              # solo lectura
  python verificar_comprobantes.py --escribir                   # + pago de prueba confirmado
  python verificar_comprobantes.py --api http://127.0.0.1:18000/api ...   # contra una API local
"""

import argparse
import getpass
import json
import sys
import urllib.error
import urllib.request

API_POR_DEFECTO = "https://vanfull-api.onrender.com/api"
IMPORTE_PRUEBA = 1234.50  # distinguible a simple vista, con decimales
CLAVES = {
    "id_comprobante", "tipo", "id_pago", "id_contratacion", "id_movimiento_cuenta",
    "fecha_hora", "importe", "medio_pago",
}
TIPOS = {"RECIBO", "FACTURA", "NOTA_DE_CREDITO", "NOTA_DE_DEBITO"}
ORIGEN_POR_TIPO = {
    "RECIBO": "id_pago", "FACTURA": "id_contratacion",
    "NOTA_DE_CREDITO": "id_movimiento_cuenta", "NOTA_DE_DEBITO": "id_movimiento_cuenta",
}

resultados = []


def verificar(ok, mensaje):
    resultados.append(bool(ok))
    print(("OK  " if ok else "NO  ") + mensaje)
    return ok


def _json(cuerpo):
    try:
        return json.loads(cuerpo.decode("utf-8"))
    except Exception:
        return {"_texto": cuerpo[:200].decode("utf-8", "replace")}


def llamar(base, metodo, ruta, token=None, cuerpo=None):
    datos = None if cuerpo is None else json.dumps(cuerpo).encode("utf-8")
    pedido = urllib.request.Request(base + ruta, data=datos, method=metodo)
    pedido.add_header("Accept", "application/json")
    if datos is not None:
        pedido.add_header("Content-Type", "application/json")
    if token:
        pedido.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(pedido, timeout=120) as r:  # Render dormido tarda cerca de 1 min
            return r.status, _json(r.read())
    except urllib.error.HTTPError as e:
        return e.code, _json(e.read())


def codigo_de(cuerpo):
    return (cuerpo.get("error") or {}).get("codigo") if isinstance(cuerpo, dict) else None


def login(base, identificador, rotulo):
    clave = getpass.getpass(f"Contrasena de {rotulo} ({identificador}) [no se ve]: ")
    if not clave:
        return None
    estado, cuerpo = llamar(base, "POST", "/auth/login", cuerpo={"identificador_acceso": identificador, "password": clave})
    token = cuerpo.get("access_token") if estado == 200 and isinstance(cuerpo, dict) else None
    verificar(token, f"login de {rotulo} ({'200' if token else f'{estado}, {codigo_de(cuerpo)}'})")
    return token


def forma(c):
    """El comprobante tiene la forma del contrato y es coherente consigo mismo (MR-R28)."""
    if set(c) != CLAVES:
        return f"claves distintas: faltan {sorted(CLAVES - set(c))}, sobran {sorted(set(c) - CLAVES)}"
    if c["tipo"] not in TIPOS:
        return f"tipo desconocido: {c['tipo']}"
    origenes = [k for k in ("id_pago", "id_contratacion", "id_movimiento_cuenta") if c[k] is not None]
    if origenes != [ORIGEN_POR_TIPO[c["tipo"]]]:
        return f"origen incoherente: {c['tipo']} con {origenes}"
    if c["importe"] is not None and not isinstance(c["importe"], (int, float)):
        return f"importe no numerico: {c['importe']!r}"
    return None


def tabla(lista):
    if not lista:
        print("    (sin comprobantes)")
    for c in lista:
        print(f"    #{c['id_comprobante']:<4} {c['tipo']:<16} importe={c['importe']!s:<9} medio={c['medio_pago']!s:<14} "
              f"fecha={c['fecha_hora']} origen={[k for k in ORIGEN_POR_TIPO.values() if c.get(k) is not None]}")


def listar(base, token):
    estado, cuerpo = llamar(base, "GET", "/pasajeros/me/comprobantes", token)
    return estado, (cuerpo if isinstance(cuerpo, list) else None), cuerpo


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--api", default=API_POR_DEFECTO, help="URL base de la API, con /api")
    ap.add_argument("--pasajero", default="pasajero2@vanfull.test")
    ap.add_argument("--otro-pasajero", default="pasajero1@vanfull.test", help="para comprobar que no ve lo ajeno")
    ap.add_argument("--admin", default="admin1@vanfull.test")
    ap.add_argument("--escribir", action="store_true", help="crea y confirma UN pago de prueba (ESCRIBE en la base)")
    a = ap.parse_args()
    base = a.api.rstrip("/")
    print(f"API: {base}\nModo: {'LECTURA + ESCRITURA (pide confirmacion)' if a.escribir else 'SOLO LECTURA'}\n")

    print("== 0. La API responde (si estaba dormida, despierta: puede tardar cerca de 1 minuto)")
    estado, cuerpo = llamar(base, "GET", "/health")
    verificar(estado == 200 and cuerpo.get("database") == "up", f"/health -> {estado} {cuerpo}")

    print("\n== 1. Lectura como pasajero")
    tok_p = login(base, a.pasajero, "pasajero")
    if not tok_p:
        print("Sin sesion de pasajero no hay nada mas que verificar.")
        return 1
    estado, lista, crudo = listar(base, tok_p)
    if not verificar(estado == 200 and lista is not None, f"GET /pasajeros/me/comprobantes -> {estado}"):
        print("    ", crudo)
        return 1
    print(f"    {len(lista)} comprobante(s) propios:")
    tabla(lista)
    for c in lista:
        problema = forma(c)
        verificar(problema is None, f"#{c['id_comprobante']} tiene la forma del contrato" + (f" ({problema})" if problema else ""))
        estado, det = llamar(base, "GET", f"/pasajeros/me/comprobantes/{c['id_comprobante']}", tok_p)
        verificar(estado == 200 and det == c, f"#{c['id_comprobante']} el detalle coincide con la lista ({estado})")
    estado, det = llamar(base, "GET", "/pasajeros/me/comprobantes/999999999", tok_p)
    verificar(estado == 404 and codigo_de(det) == "COMPROBANTE_NO_ENCONTRADO",
              f"un id inexistente -> {estado} {codigo_de(det)} (se espera 404 COMPROBANTE_NO_ENCONTRADO)")
    estado, _ = llamar(base, "GET", "/pasajeros/me/comprobantes")
    verificar(estado == 401, f"sin sesion -> {estado} (se espera 401)")
    estado, deuda = llamar(base, "GET", "/pasajeros/me/deuda", tok_p)
    saldo_antes = deuda.get("saldo") if estado == 200 else None
    print(f"    (informativo) deuda del pasajero: {deuda if estado == 200 else estado}")

    if not a.escribir:
        print("\nSolo lectura: no se escribio nada.")
        if not lista:
            print("Este pasajero no tiene comprobantes: para verlos en la app hay que confirmar un pago (--escribir).")
        return resumen()

    print("\n== 2. ESCRITURA: un pago de prueba, confirmado")
    print(f"Va a crear UN pago de {IMPORTE_PRUEBA} por TRANSFERENCIA para {a.pasajero} y a confirmarlo como {a.admin}.")
    print("Escribe en la base y no se puede deshacer por la API (solo re-sembrando con --reiniciar).")
    if input("Escribi ESCRIBIR para seguir (cualquier otra cosa corta aca): ").strip() != "ESCRIBIR":
        print("Cortado: no se escribio nada.")
        return resumen()
    tok_a = login(base, a.admin, "administracion")
    if not tok_a:
        print("Sin sesion de administracion no se puede confirmar. No se registro ningun pago.")
        return resumen()

    estado, pago = llamar(base, "POST", "/pagos", tok_p, {"importe": IMPORTE_PRUEBA, "medio_pago": "TRANSFERENCIA"})
    if not verificar(estado == 201 and pago.get("estado") == "PENDIENTE", f"el pasajero registra el pago -> {estado} {pago.get('estado') if isinstance(pago, dict) else pago}"):
        print("    ", pago)
        return resumen()
    id_pago = pago["id_pago"]
    print(f"    pago {id_pago} PENDIENTE")
    _, lista_pend, _ = listar(base, tok_p)
    verificar(lista_pend is not None and len(lista_pend) == len(lista), "un pago PENDIENTE todavia no genera comprobante")
    estado, conf = llamar(base, "POST", f"/pagos/{id_pago}/confirmacion", tok_a, {"decision": "CONFIRMADO"})
    verificar(estado == 200 and conf.get("estado") == "CONFIRMADO", f"administracion confirma el pago -> {estado} {conf.get('estado') if isinstance(conf, dict) else conf}")

    print("\n== 3. El recibo aparece")
    estado, lista2, _ = listar(base, tok_p)
    nuevos = [c for c in (lista2 or []) if c["id_pago"] == id_pago]
    verificar(len(nuevos) == 1, f"aparece exactamente un comprobante del pago {id_pago}")
    verificar(lista2 is not None and len(lista2) == len(lista) + 1, f"la lista paso de {len(lista)} a {len(lista2) if lista2 is not None else '?'}")
    if nuevos:
        r = nuevos[0]
        verificar(r["tipo"] == "RECIBO", f"es un RECIBO ({r['tipo']})")
        verificar(r["importe"] == IMPORTE_PRUEBA, f"importe {r['importe']} == {IMPORTE_PRUEBA}")
        verificar(r["medio_pago"] == "TRANSFERENCIA", f"medio {r['medio_pago']}")
        verificar(r["fecha_hora"] is not None, f"fecha_hora presente ({r['fecha_hora']})")
        verificar(forma(r) is None, "tiene la forma del contrato")
        estado, det = llamar(base, "GET", f"/pasajeros/me/comprobantes/{r['id_comprobante']}", tok_p)
        verificar(estado == 200 and det == r, "el detalle coincide con la lista")
        print(f"\n    >>> Buscalo en la app: Cuenta -> Mis comprobantes -> comprobante #{r['id_comprobante']} "
              f"(RECIBO, importe {IMPORTE_PRUEBA}, TRANSFERENCIA, Pago N.o {id_pago}).")
    estado, deuda2 = llamar(base, "GET", "/pasajeros/me/deuda", tok_p)
    print(f"    (informativo) deuda antes: saldo={saldo_antes}; despues: {deuda2 if estado == 200 else estado}")

    print("\n== 4. Alcance: lo ajeno no se ve, y otro rol no entra")
    estado, _ = llamar(base, "GET", "/pasajeros/me/comprobantes", tok_a)
    verificar(estado == 403, f"administracion en la ruta del pasajero -> {estado} (se espera 403)")
    tok_o = login(base, a.otro_pasajero, "otro pasajero (Enter para omitir)")
    if tok_o and nuevos:
        _, lista_o, _ = listar(base, tok_o)
        verificar(lista_o is not None and all(c["id_comprobante"] != nuevos[0]["id_comprobante"] for c in lista_o),
                  "el otro pasajero NO ve el recibo en su lista")
        estado, det = llamar(base, "GET", f"/pasajeros/me/comprobantes/{nuevos[0]['id_comprobante']}", tok_o)
        verificar(estado == 404 and codigo_de(det) == "COMPROBANTE_NO_ENCONTRADO",
                  f"el otro pasajero pide ese id -> {estado} {codigo_de(det)} (el mismo 404 que un id inexistente)")
    return resumen()


def resumen():
    malos = resultados.count(False)
    print(f"\n{'=' * 60}\n{len(resultados) - malos} OK, {malos} NO")
    return 1 if malos else 0


if __name__ == "__main__":
    sys.exit(main())

# -*- coding: utf-8 -*-
"""Dibuja los diagramas de componentes y de despliegue de VanFull (PNG)."""
import math, os
from PIL import Image, ImageDraw, ImageFont

S = 2  # supersampling
FD = r"C:\Windows\Fonts"
INK, GRAPH, GOLD, LIGHT, MID, WHITE = "#17171A", "#5F5F61", "#D9A521", "#F2F2F2", "#B4B4B7", "#FFFFFF"
GOLD_L = "#F6E7B8"

def F(size, bold=False, mono=False):
    name = ("consolab.ttf" if bold else "consola.ttf") if mono else ("arialbd.ttf" if bold else "arial.ttf")
    p = os.path.join(FD, name)
    if not os.path.exists(p): p = os.path.join(FD, "arialbd.ttf" if bold else "arial.ttf")
    return ImageFont.truetype(p, int(size * S))

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGB", (w * S, h * S), WHITE)
        self.d = ImageDraw.Draw(self.im)
    def save(self, path):
        self.im.resize((self.w, self.h), Image.LANCZOS).save(path, optimize=True)

    # ---------- texto
    def wrap(self, text, font, maxw):
        lines = []
        for para in text.split("\n"):
            words, cur = para.split(" "), ""
            for w in words:
                t = (cur + " " + w).strip()
                if self.d.textlength(t, font=font) <= maxw * S or not cur: cur = t
                else: lines.append(cur); cur = w
            lines.append(cur)
        return lines
    def text(self, x, y, text, size=24, bold=False, fill=INK, maxw=None, center=False, mono=False, lh=1.28):
        font = F(size, bold, mono)
        lines = self.wrap(text, font, maxw) if maxw else text.split("\n")
        cy = y
        for ln in lines:
            w = self.d.textlength(ln, font=font) / S
            tx = x - w / 2 if center else x
            self.d.text((tx * S, cy * S), ln, font=font, fill=fill)
            cy += size * lh
        return cy - y
    def textheight(self, text, size, maxw, bold=False, mono=False, lh=1.28):
        font = F(size, bold, mono)
        return len(self.wrap(text, font, maxw)) * size * lh

    # ---------- cajas
    def box(self, x0, y0, x1, y1, fill=LIGHT, outline=INK, width=3, dashed=False, radius=14):
        if not dashed:
            self.d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius * S, fill=fill, outline=outline, width=width * S)
        else:
            self.d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius * S, fill=fill)
            self.dash_rect(x0, y0, x1, y1, outline, width)
    def dash_rect(self, x0, y0, x1, y1, color, width, dash=14, gap=9):
        for (a, b) in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
            self.dashed_line(a, b, color, width, dash, gap)
    def dashed_line(self, a, b, color, width, dash=14, gap=9):
        (x0, y0), (x1, y1) = a, b
        L = math.hypot(x1 - x0, y1 - y0)
        if L == 0: return
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        pos = 0
        while pos < L:
            e = min(pos + dash, L)
            self.d.line([(x0 + ux * pos) * S, (y0 + uy * pos) * S, (x0 + ux * e) * S, (y0 + uy * e) * S], fill=color, width=int(width * S))
            pos += dash + gap
    def card(self, x0, y0, x1, y1, title, body="", fill=LIGHT, dashed=False, outline=INK, tsize=27, bsize=22, mono_title=False, pad=18, center=False):
        self.box(x0, y0, x1, y1, fill=fill, outline=outline, dashed=dashed)
        cx = (x0 + x1) / 2
        ty = y0 + pad - 2
        h = self.text(cx if center else x0 + pad, ty, title, tsize, True, INK, maxw=x1 - x0 - 2 * pad, center=center, mono=mono_title)
        if body:
            self.text(cx if center else x0 + pad, ty + h + 5, body, bsize, False, GRAPH if fill != GOLD else INK, maxw=x1 - x0 - 2 * pad, center=center)
    def chip(self, x0, y0, x1, y1, text, size=21, fill=WHITE):
        self.box(x0, y0, x1, y1, fill=fill, outline=GRAPH, width=2, radius=10)
        self.text((x0 + x1) / 2, (y0 + y1) / 2 - size * 0.65, text, size, True, INK, maxw=x1 - x0 - 14, center=True)

    # ---------- flechas
    def arrow(self, pts, color=GRAPH, width=3, dashed=False, head=18, both=False):
        for a, b in zip(pts[:-1], pts[1:]):
            if dashed: self.dashed_line(a, b, color, width, 12, 8)
            else: self.d.line([a[0] * S, a[1] * S, b[0] * S, b[1] * S], fill=color, width=int(width * S))
        self.arrowhead(pts[-2], pts[-1], color, head)
        if both: self.arrowhead(pts[1], pts[0], color, head)
    def arrowhead(self, a, b, color, head):
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        p1 = (b[0] - head * math.cos(ang - 0.42), b[1] - head * math.sin(ang - 0.42))
        p2 = (b[0] - head * math.cos(ang + 0.42), b[1] - head * math.sin(ang + 0.42))
        self.d.polygon([(b[0] * S, b[1] * S), (p1[0] * S, p1[1] * S), (p2[0] * S, p2[1] * S)], fill=color)
    def label(self, x, y, text, size=19, center=True, color=GRAPH):
        font = F(size, False)
        w = self.d.textlength(text, font=font) / S
        x0 = x - w / 2 if center else x
        self.d.rectangle([(x0 - 6) * S, (y - 3) * S, (x0 + w + 6) * S, (y + size * 1.3) * S], fill=WHITE)
        self.d.text((x0 * S, y * S), text, font=font, fill=color)

def legend(c, x, y, items):
    for kind, txt in items:
        if kind == "solid": c.box(x, y, x + 54, y + 30, fill=LIGHT, outline=INK, width=3, radius=6)
        elif kind == "dashed": c.box(x, y, x + 54, y + 30, fill=WHITE, outline=GRAPH, dashed=True, width=3, radius=6)
        elif kind == "gold": c.box(x, y, x + 54, y + 30, fill=GOLD, outline=GRAPH, dashed=True, width=3, radius=6)
        c.text(x + 68, y + 1, txt, 21, False, INK)
        x += 68 + c.d.textlength(txt, font=F(21)) / S + 40

# ======================================================================== COMPONENTES
def componentes(path):
    c = Canvas(2000, 1760)
    c.text(40, 26, "Diagrama de componentes · arquitectura lógica de VanFull", 38, True)
    # --- clientes
    c.box(40, 100, 1180, 300, fill=LIGHT, outline=INK)
    c.text(62, 114, "Aplicación Flutter · Web y Mobile", 28, True)
    c.text(62, 152, "Vista del modelo MVC: muestra y valida la forma, no decide reglas", 21, False, GRAPH)
    for i, t in enumerate(["Pasajero", "Chofer", "Administrador y dueño", "Cliente corporativo"]):
        x0 = 62 + i * 278
        c.chip(x0, 205, x0 + 262, 275, t, 21)
    c.card(1260, 100, 1560, 300, "WhatsApp", "Canal alternativo de atención. Configuración pendiente de definir", fill=LIGHT, dashed=True, outline=GRAPH, tsize=27, bsize=21)
    # --- backend
    c.box(40, 400, 1560, 1330, fill=WHITE, outline=INK, width=4, radius=18)
    c.text(66, 412, "Backend · FastAPI (Python)", 30, True)
    c.text(66, 452, "Controlador del modelo MVC y autoridad de las reglas", 21, False, GRAPH)
    # columna izquierda: routers -> services -> models
    c.card(70, 520, 780, 660, "routers/", "Reciben el pedido y lo derivan, sin lógica. Hoy existe solo /health", fill=LIGHT, tsize=28, mono_title=True, bsize=21)
    c.card(70, 740, 780, 930, "services/", "Las 31 reglas de negocio: cupos, pagos, cancelaciones, permisos. Es el corazón del sistema", fill=GOLD, dashed=True, outline=INK, tsize=28, mono_title=True, bsize=21)
    c.card(70, 1010, 780, 1160, "models/", "SQLAlchemy 2.0 asíncrono. La única capa que habla con la base", fill=WHITE, dashed=True, outline=GRAPH, tsize=28, mono_title=True, bsize=21)
    c.arrow([(425, 660), (425, 740)], INK, 4)
    c.arrow([(425, 930), (425, 1010)], INK, 4)
    # schemas al lado de routers
    c.card(830, 520, 1180, 660, "schemas/", "Pydantic: forma de los datos que entran y salen", fill=WHITE, dashed=True, outline=GRAPH, tsize=28, mono_title=True, bsize=21)
    c.arrow([(780, 590), (830, 590)], GRAPH, 3, head=14, both=True)
    # agent
    c.card(830, 700, 1530, 870, "agent/ · asistente AG-01", "tools.py: 13 herramientas, una por caso de uso, con el prompt base.\nopenrouter_client.py: llama al modelo principal y, si falla, al de respaldo", fill=LIGHT, tsize=26, bsize=21)
    c.arrow([(830, 800), (780, 800)], INK, 4)
    c.label(805, 768, "tools", 18)
    # core
    c.card(1220, 520, 1530, 660, "core/", "config y database (existen). Seguridad: JWT y roles (planificado)", fill=LIGHT, tsize=28, mono_title=True, bsize=19)
    # integraciones
    c.card(830, 990, 1530, 1160, "Integraciones", "Webhook de Mercado Pago, Google Maps Routes y mensajería de WhatsApp. Las llama solo el servidor", fill=WHITE, dashed=True, outline=GRAPH, tsize=26, bsize=21)
    c.arrow([(780, 900), (805, 900), (805, 1075), (830, 1075)], GRAPH, 3, head=16)
    # --- base de datos
    c.card(40, 1440, 780, 1600, "PostgreSQL 16", "35 tablas, 54 claves foráneas, restricciones CHECK y XOR. Modelo ya ejecutado y verificado (schema.sql)", fill=LIGHT, tsize=28, bsize=21)
    c.arrow([(425, 1160), (425, 1330), (425, 1440)], INK, 4)
    c.label(425, 1350, "SQL", 19)
    # --- externos
    c.text(1640, 410, "Servicios externos", 24, True, GRAPH)
    c.card(1620, 460, 1960, 640, "OpenRouter", "MiniMax M3 (principal) y Nemotron 3 Super (respaldo)", fill=LIGHT, tsize=26, bsize=20)
    c.card(1620, 700, 1960, 840, "Mercado Pago", "Modo de prueba", fill=LIGHT, dashed=True, outline=GRAPH, tsize=26, bsize=20)
    c.card(1620, 900, 1960, 1060, "Google Maps", "Routes API: recorridos y tránsito", fill=LIGHT, dashed=True, outline=GRAPH, tsize=26, bsize=20)
    # flechas externas
    c.arrow([(1530, 790), (1597, 790), (1597, 550), (1620, 550)], INK, 4)
    c.label(1568, 505, "HTTPS", 17)
    c.arrow([(1530, 1040), (1575, 1040), (1575, 770), (1620, 770)], GRAPH, 3, dashed=True, head=16, both=True)
    c.arrow([(1530, 1115), (1605, 1115), (1605, 1000), (1620, 1000)], GRAPH, 3, dashed=True, head=16)
    # clientes -> backend
    c.arrow([(700, 300), (700, 520)], INK, 4)
    c.label(708, 342, "REST / JSON · contrato OpenAPI", 19, center=False)
    c.arrow([(1380, 300), (1380, 482), (1200, 482), (1200, 700)], GRAPH, 3, dashed=True)
    c.label(1388, 330, "mensajes", 19, center=False)
    # nota IA
    c.box(830, 1215, 1530, 1300, fill=GOLD_L, outline=GOLD, width=3, radius=12)
    c.text(850, 1224, "La IA no accede a la base de datos: solo llama herramientas del servidor, que valida todo.", 21, True, INK, maxw=660)
    legend(c, 40, 1670, [("solid", "Existe en el repositorio"), ("dashed", "Planificado, todavía sin código"), ("gold", "Reglas de negocio (31)")])
    c.save(path)

# ======================================================================== DESPLIEGUE
def despliegue(path):
    c = Canvas(2000, 1380)
    c.text(40, 26, "Diagrama de despliegue · cómo corre VanFull", 38, True)
    # ---- desarrollo
    c.box(40, 100, 800, 760, fill=WHITE, outline=INK, width=4, radius=18)
    c.text(66, 114, "DESARROLLO · en la computadora de cada integrante", 25, True)
    c.text(66, 150, "Existe: definido en docker-compose.yml", 21, False, GRAPH)
    c.box(70, 200, 770, 730, fill=LIGHT, outline=GRAPH, width=2, radius=14)
    c.text(92, 214, "Docker Compose", 26, True)
    c.card(100, 270, 740, 440, "backend", "FastAPI con uvicorn, recarga automática.\nPuerto 8000. El código de la carpeta backend/ queda montado", fill=WHITE, tsize=26, bsize=21, mono_title=True)
    c.card(100, 540, 740, 700, "db", "PostgreSQL 16. Puerto 5432.\nLos datos viven en el volumen pgdata", fill=WHITE, tsize=26, bsize=21, mono_title=True)
    c.arrow([(420, 440), (420, 540)], INK, 4)
    c.label(425, 478, "SQL · espera a que la base esté lista", 18, center=False)
    # ---- entrega
    c.box(860, 100, 1960, 940, fill=WHITE, outline=INK, width=4, radius=18, dashed=True)
    c.text(886, 114, "ENTREGA · sin costo", 25, True)
    c.text(886, 150, "Planificado: se provisiona en la semana 12. Todavía no existe", 21, False, GRAPH)
    # GitHub
    c.card(890, 210, 1290, 360, "GitHub", "Repositorio público. Desde acá se publica y se despliega", fill=LIGHT, tsize=26, bsize=20)
    # Pages
    c.card(1330, 210, 1930, 360, "GitHub Pages", "Versión web de la aplicación Flutter (archivos estáticos)", fill=LIGHT, dashed=True, outline=GRAPH, tsize=26, bsize=20)
    c.arrow([(1290, 285), (1330, 285)], INK, 4)
    c.label(1310, 250, "build", 17)
    # Render
    c.card(890, 540, 1480, 720, "Render · servicio web", "FastAPI en la nube. Plan gratis: se duerme a los 15 min sin tráfico y tarda cerca de 1 min en despertar", fill=GOLD_L, dashed=True, outline=INK, tsize=25, bsize=20)
    c.arrow([(1090, 360), (1090, 540)], INK, 4)
    c.label(1096, 440, "deploy", 18, center=False)
    # Neon
    c.card(1520, 540, 1930, 720, "Neon · PostgreSQL", "Base gestionada. Plan gratis: 1 GB; se duerme a los 5 min", fill=GOLD_L, dashed=True, outline=INK, tsize=25, bsize=20)
    c.arrow([(1480, 630), (1520, 630)], INK, 4)
    c.label(1500, 590, "SQL", 17)
    # Dispositivos
    c.box(1330, 405, 1930, 485, fill=LIGHT, outline=INK)
    c.text(1630, 418, "Navegador y teléfono", 23, True, INK, center=True)
    c.text(1630, 450, "pasajero, chofer y administración", 19, False, GRAPH, center=True)
    c.arrow([(1630, 405), (1630, 360)], GRAPH, 3, head=14)
    c.label(1638, 372, "descarga la web", 17, center=False)
    c.arrow([(1500, 485), (1500, 512), (1180, 512), (1180, 540)], GRAPH, 3, head=14)
    c.label(1340, 515, "HTTPS · JSON", 17)
    # nota hosting
    c.box(1120, 770, 1930, 910, fill=LIGHT, outline=GRAPH, width=2, radius=12)
    c.text(1140, 784, "Antes de cada demostración hay que despertar los servicios (abrir /health y hacer una consulta). Si el producto se vende, se pasa a un plan pago cambiando la variable DATABASE_URL.", 20, False, INK, maxw=770)
    # ---- externos
    c.text(40, 930, "Servicios externos · los llama solo el servidor", 25, True, GRAPH)
    ext = [("OpenRouter", "MiniMax M3 y Nemotron 3 Super"), ("Mercado Pago", "Modo de prueba. Avisa por webhook"),
           ("Google Maps", "Routes API: recorridos y tránsito"), ("WhatsApp", "Mensajería. Configuración pendiente")]
    xs = []
    for i, (t, b) in enumerate(ext):
        x0 = 40 + i * 490
        c.card(x0, 1060, x0 + 455, 1220, t, b, fill=LIGHT, dashed=(i > 0), outline=INK if i == 0 else GRAPH, tsize=26, bsize=21)
        xs.append(x0 + 227)
    # flechas desde Render hacia los externos (bus horizontal)
    BUS = 1000
    c.d.line([1010 * S, 720 * S, 1010 * S, BUS * S], fill=GRAPH, width=3 * S)
    c.label(1016, 830, "HTTPS", 17, center=False)
    c.d.line([min(xs) * S, BUS * S, max(xs) * S, BUS * S], fill=GRAPH, width=3 * S)
    for i, x in enumerate(xs):
        c.d.line([x * S, BUS * S, x * S, 1060 * S], fill=GRAPH, width=3 * S)
        c.arrowhead((x, 1030), (x, 1060), GRAPH, 15)
        if i in (1, 3): c.arrowhead((x, 1030), (x, BUS), GRAPH, 15)
    c.text(40, 1250, "En desarrollo, el mismo backend usa las claves de cada integrante (archivo .env, que nunca se sube al repositorio).", 20, False, GRAPH, maxw=1900)
    legend(c, 40, 1310, [("solid", "Existe hoy"), ("dashed", "Planificado")])
    c.save(path)

if __name__ == "__main__":
    os.makedirs("diag", exist_ok=True)
    componentes("diag/componentes.png"); despliegue("diag/despliegue.png")
    for n in ("componentes", "despliegue"):
        im = Image.open("diag/%s.png" % n); print(n, im.size, os.path.getsize("diag/%s.png" % n), "bytes")

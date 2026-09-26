// Conversor Markdown -> Word para los documentos del PC1 de VanFull.
// Cubre el subconjunto de Markdown que usan esos documentos: encabezados, párrafos con
// negrita/código/enlaces, tablas, viñetas, listas numeradas, bloques de código, citas y reglas.
// Uso: node md2docx.js <entrada.md> <salida.docx> "<Título>"

const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, WidthType, ShadingType, BorderStyle, AlignmentType,
  LevelFormat, ExternalHyperlink, convertInchesToTwip
} = require('docx');

// A4 con márgenes de 1", que es lo que usa el resto de la documentación del equipo
const ANCHO_PAGINA = 11906, ALTO_PAGINA = 16838, MARGEN = 1440;
const ANCHO_UTIL = ANCHO_PAGINA - MARGEN * 2;   // 9026 DXA

const GRAFITO = '414143';   // encabezado de tabla: el mismo gris de la franja de la combi
const DORADO  = '8C6A15';   // dorado legible sobre blanco (4.63:1)
const TENUE   = 'F2F2F2';

// ---------- formato dentro de una línea ----------
function trozos(texto, base = {}) {
  const salida = [];
  // negrita | código | enlace markdown | URL suelta
  const re = /\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)|(https?:\/\/[^\s)|]+)/g;
  let i = 0, m;
  const plano = (t) => { if (t) salida.push(new TextRun({ text: t, ...base })); };
  while ((m = re.exec(texto)) !== null) {
    plano(texto.slice(i, m.index));
    if (m[1] !== undefined) {
      salida.push(new TextRun({ text: m[1], ...base, bold: true }));
    } else if (m[2] !== undefined) {
      salida.push(new TextRun({ text: m[2], ...base, font: 'Consolas', size: 19 }));
    } else if (m[3] !== undefined) {
      salida.push(new ExternalHyperlink({
        link: m[4],
        children: [new TextRun({ text: m[3], ...base, color: '0563C1', underline: {} })]
      }));
    } else {
      salida.push(new ExternalHyperlink({
        link: m[5],
        children: [new TextRun({ text: m[5], ...base, color: '0563C1', underline: {}, size: 19 })]
      }));
    }
    i = re.lastIndex;
  }
  plano(texto.slice(i));
  return salida.length ? salida : [new TextRun({ text: '', ...base })];
}

// quita el resaltado de markdown para celdas donde solo interesa el texto
const limpiar = (t) => t.replace(/\*\*(.+?)\*\*/g, '$1').replace(/`([^`]+)`/g, '$1');

// ---------- tablas ----------
function celda(texto, { encabezado = false, ancho }) {
  const alineada = /^-+:$/.test(texto);
  return new TableCell({
    width: { size: ancho, type: WidthType.DXA },
    shading: { type: ShadingType.CLEAR, color: 'auto', fill: encabezado ? GRAFITO : 'FFFFFF' },
    margins: { top: 60, bottom: 60, left: 108, right: 108 },
    children: [new Paragraph({
      alignment: alineada ? AlignmentType.RIGHT : AlignmentType.LEFT,
      spacing: { before: 0, after: 0 },
      children: trozos(texto, encabezado ? { bold: true, color: 'FFFFFF', size: 19 } : { size: 19 })
    })]
  });
}

function tabla(filas) {
  const columnas = Math.max(...filas.map((f) => f.length));
  const base = Math.floor(ANCHO_UTIL / columnas);
  const anchos = Array.from({ length: columnas }, (_, i) =>
    i === columnas - 1 ? ANCHO_UTIL - base * (columnas - 1) : base);
  const borde = { style: BorderStyle.SINGLE, size: 2, color: 'BFBFBF' };
  return new Table({
    width: { size: ANCHO_UTIL, type: WidthType.DXA },
    columnWidths: anchos,
    borders: { top: borde, bottom: borde, left: borde, right: borde,
               insideHorizontal: borde, insideVertical: borde },
    rows: filas.map((f, fi) => new TableRow({
      tableHeader: fi === 0,
      children: anchos.map((a, ci) => celda(f[ci] ?? '', { encabezado: fi === 0, ancho: a }))
    }))
  });
}

// ---------- recorrido del documento ----------
function convertir(md) {
  const lineas = md.split(/\r?\n/);
  const hijos = [];
  let i = 0;

  const esFilaTabla = (l) => l.trim().startsWith('|') && l.trim().endsWith('|');
  const celdas = (l) => l.trim().slice(1, -1).split('|').map((c) => c.trim());
  const esSeparador = (l) => celdas(l).every((c) => /^:?-{2,}:?$/.test(c));

  while (i < lineas.length) {
    const linea = lineas[i];
    const t = linea.trim();

    if (t === '') { i++; continue; }

    // regla horizontal -> párrafo con borde inferior
    if (/^---+$/.test(t)) {
      hijos.push(new Paragraph({
        spacing: { before: 120, after: 160 },
        border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: 'BFBFBF' } },
        children: [new TextRun('')]
      }));
      i++; continue;
    }

    // bloque de código
    if (t.startsWith('```')) {
      i++;
      const cuerpo = [];
      while (i < lineas.length && !lineas[i].trim().startsWith('```')) cuerpo.push(lineas[i++]);
      i++;
      cuerpo.forEach((l, n) => hijos.push(new Paragraph({
        spacing: { before: n === 0 ? 100 : 0, after: n === cuerpo.length - 1 ? 140 : 0 },
        shading: { type: ShadingType.CLEAR, color: 'auto', fill: TENUE },
        indent: { left: 180, right: 180 },
        children: [new TextRun({ text: l || ' ', font: 'Consolas', size: 18 })]
      })));
      continue;
    }

    // encabezados
    const h = /^(#{1,4})\s+(.*)$/.exec(t);
    if (h) {
      const nivel = [HeadingLevel.HEADING_1, HeadingLevel.HEADING_2,
                     HeadingLevel.HEADING_3, HeadingLevel.HEADING_4][h[1].length - 1];
      hijos.push(new Paragraph({
        heading: nivel,
        spacing: { before: h[1].length === 1 ? 240 : 220, after: 110 },
        children: trozos(h[2])
      }));
      i++; continue;
    }

    // tabla
    if (esFilaTabla(linea) && i + 1 < lineas.length && esSeparador(lineas[i + 1])) {
      const filas = [celdas(linea)];
      i += 2;
      while (i < lineas.length && esFilaTabla(lineas[i])) filas.push(celdas(lineas[i++]));
      hijos.push(tabla(filas));
      hijos.push(new Paragraph({ spacing: { after: 140 }, children: [new TextRun('')] }));
      continue;
    }

    // cita
    if (t.startsWith('>')) {
      hijos.push(new Paragraph({
        spacing: { before: 100, after: 140 },
        indent: { left: 340 },
        border: { left: { style: BorderStyle.SINGLE, size: 12, color: DORADO, space: 12 } },
        children: trozos(t.replace(/^>\s?/, ''), { italics: true, color: '404040' })
      }));
      i++; continue;
    }

    // viñeta
    const v = /^[-*]\s+(.*)$/.exec(t);
    if (v) {
      hijos.push(new Paragraph({
        numbering: { reference: 'vinetas', level: 0 },
        spacing: { after: 60 },
        children: trozos(v[1])
      }));
      i++; continue;
    }

    // lista numerada
    const n = /^(\d+)\.\s+(.*)$/.exec(t);
    if (n) {
      hijos.push(new Paragraph({
        numbering: { reference: 'numerada', level: 0 },
        spacing: { after: 60 },
        children: trozos(n[2])
      }));
      i++; continue;
    }

    // párrafo: se juntan las líneas siguientes hasta un renglón en blanco
    const parrafo = [t];
    i++;
    while (i < lineas.length) {
      const s = lineas[i].trim();
      if (s === '' || /^(#{1,4}\s|[-*]\s|\d+\.\s|>|```|---+$)/.test(s) || esFilaTabla(lineas[i])) break;
      parrafo.push(s); i++;
    }
    hijos.push(new Paragraph({ spacing: { after: 140 }, children: trozos(parrafo.join(' ')) }));
  }
  return hijos;
}

// ---------- armado ----------
const [entrada, salida, titulo] = process.argv.slice(2);
const doc = new Document({
  creator: 'Equipo VanFull',
  title: titulo || '',
  description: 'Proyecto VanFull — Trabajo de Campo — PC1',
  numbering: {
    config: [
      { reference: 'vinetas', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•',
          alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 460, hanging: 240 } } } }] },
      { reference: 'numerada', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.',
          alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 460, hanging: 240 } } } }] }
    ]
  },
  styles: {
    default: {
      document: { run: { font: 'Calibri', size: 21 }, paragraph: { spacing: { line: 276 } } },
      heading1: { run: { font: 'Calibri', size: 34, bold: true, color: '17171A' } },
      heading2: { run: { font: 'Calibri', size: 27, bold: true, color: GRAFITO } },
      heading3: { run: { font: 'Calibri', size: 23, bold: true, color: GRAFITO } },
      heading4: { run: { font: 'Calibri', size: 21, bold: true, color: GRAFITO } }
    }
  },
  sections: [{
    properties: { page: { size: { width: ANCHO_PAGINA, height: ALTO_PAGINA },
                          margin: { top: MARGEN, bottom: MARGEN, left: MARGEN, right: MARGEN } } },
    children: convertir(fs.readFileSync(entrada, 'utf8'))
  }]
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(salida, buf);
  console.log(`  ${salida.split(/[\\/]/).pop()}  ${(buf.length / 1024).toFixed(1)} KB`);
});

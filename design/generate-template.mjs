import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {SceneGraph} from '@open-pencil/scene-graph';
import {IORegistry, BUILTIN_IO_FORMATS} from '@open-pencil/core/io';
import {meta, schemes, modeNames, variables, colors, components, rgba, show, sources, pageIndex, coverFields} from './tokens.mjs';
import {drawComponent} from './components.mjs';

const dir = path.dirname(fileURLToPath(import.meta.url));
const faces = JSON.parse(execFileSync(process.env.PYTHON || 'python3', [path.join(dir, 'font-outlines.py')], {maxBuffer: 16 * 1024 * 1024}));
for (const face of Object.values(faces)) for (const glyph of Object.values(face)) glyph[1] = Uint8Array.from(Buffer.from(glyph[1], 'base64'));

const g = new SceneGraph();
const cover = g.getPages()[0];
cover.name = 'Cover';
const [tokensPage, componentsPage] = ['Tokens', 'Components'].map((name) => g.addPage(name));

const collection = g.createCollection(meta.name);
collection.modes[0].name = modeNames[0];
for (const name of modeNames.slice(1)) g.createMode(collection.id, name);
const modeIds = collection.modes.map((m) => m.modeId);
const vars = {};
for (const v of variables) {
  const value = (i) => (v.type === 'COLOR' ? rgba(v.values[i]) : v.values[i]);
  vars[v.name] = g.createVariable(v.name, v.type, collection.id, value(0));
  modeIds.slice(1).forEach((id, i) => { vars[v.name].valuesByMode[id] = value(i + 1); });
}

const documentColor = (h) => ({r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255, a: 1});
// A bound paint takes its alpha from the variable, so .opacity(x) from the views goes on the node (alpha below).
function ink(node, field, color, {weight = 1} = {}) {
  if (!color) return;
  const token = vars[color], c = token ? token.valuesByMode[modeIds[0]] : documentColor(color);
  node[field] = [{type: 'SOLID', color: {...c, a: 1}, opacity: c.a, visible: true}];
  if (field === 'strokes') { node.strokeWeight = weight; node.strokeAlign = 'INSIDE'; Object.assign(node.strokes[0], {weight, align: 'INSIDE'}); }
  if (token) g.bindVariable(node.id, field + '/0/color', token.id);
}
function box(parent, name, x, y, w, h, fill = null, type = 'FRAME', alpha = 1) {
  const n = g.createNode(type, parent.id, {name, x, y, width: Math.max(0.01, w), height: Math.max(0.01, h), fills: [], clipsContent: false});
  ink(n, 'fills', fill);
  if (alpha !== 1) n.opacity = alpha;
  return n;
}
const faceOf = (font, weight) => faces[font + [400, 500, 600, 700].reduce((a, b) => (Math.abs(weight - b) < Math.abs(weight - a) ? b : a), 400)] ?? faces[font + 400];
function measure(s, font, size, weight) {
  const face = faceOf(font, weight);
  return face ? [...s].reduce((w, ch) => w + (face[ch]?.[0] ?? 0.5) * size, 0) : s.length * size * 0.56;
}
function text(parent, s, x, y, o = {}) {
  const {size = 13, weight = 400, font = 'Inter', color, alpha = 1, align = 'LEFT', lh = Math.round(size * 1.2 + 0.5)} = o;
  const natural = Math.ceil(measure(s, font, size, weight)) + 1;
  const w = o.w ?? natural;
  const n = box(parent, o.name ?? s, x, y, w, lh, null, 'TEXT');
  Object.assign(n, {text: s, fontSize: size, fontFamily: font, fontWeight: weight, lineHeight: lh, textAlignHorizontal: align, textAutoResize: o.w ? 'HEIGHT' : 'WIDTH_AND_HEIGHT'});
  if (o.strike) n.textDecoration = 'STRIKETHROUGH';
  ink(n, 'fills', color);
  if (alpha !== 1) n.opacity = alpha;
  const face = faceOf(font, weight);
  if (face) {
    const offset = align === 'CENTER' ? (w - natural) / 2 : align === 'RIGHT' ? w - natural : 0;
    let gx = offset, i = 0;
    const glyphs = [];
    for (const ch of s) {
      const glyph = face[ch];
      if (glyph) glyphs.push({commandsBlob: glyph[1], x: gx, y: lh / 2 + size * 0.34, firstCharacter: i, fontSize: size, advance: glyph[0] * size});
      gx += (glyph?.[0] ?? 0.5) * size; i += ch.length;
    }
    n.derivedTextGlyphs = glyphs;
  }
  return n;
}
const link = (n, id) => { n.styleRuns = [{start: 0, length: n.text.length, style: {hyperlink: {type: 'NODE', value: id}}}]; };

// Cover: plain document colors, values copied from the DESIGN.md frontmatter.
const card = box(cover, 'Cover', 0, 0, 960, 0, '#ffffff');
const INK = '#1b1f24', MUTED = '#5b6470';
text(card, meta.name, 48, 48, {size: 32, weight: 700, color: INK, lh: 44});
let y = 120;
for (const [label, value] of coverFields()) {
  text(card, label, 48, y, {color: MUTED});
  text(card, value, 240, y, {color: INK, weight: 600});
  y += 28;
}
y += 20;
text(card, 'Page index', 48, y, {size: 15, weight: 700, color: INK}); y += 28;
for (const [page, summary] of pageIndex) {
  const p = g.getPages().find((x) => x.name === page);
  link(text(card, page, 48, y, {color: '#0b57d0', weight: 600}), p.id);
  text(card, summary, 240, y, {color: MUTED}); y += 26;
}
y += 20;
text(card, 'Source files', 48, y, {size: 15, weight: 700, color: INK}); y += 28;
for (const file of sources) { text(card, file, 48, y, {color: INK, size: 12}); y += 22; }
card.height = y + 40;

const SURFACE = 'board-bg', LINE = 'line', TEXT = 'text-body', SUB = 'text-meta';
function versionLabel(page) {
  const band = box(page, 'Version label', 0, -64, 900, 36, 'title-bar-bg');
  text(band, `${meta.name} · design ${meta.design_version} · product ${meta.product_version} · ${page.name}`, 14, 9, {color: TEXT, size: 13});
  band.variableModes = {[collection.id]: modeIds[0]};
}

// Tokens page: color swatches per mode, then non-color tokens grouped by prefix.
let tx = 0;
modeIds.forEach((modeId, mode) => {
  const lane = box(tokensPage, 'Colors / ' + modeNames[mode], tx, 0, 760, 80 + colors.length * 34, SURFACE);
  lane.variableModes = {[collection.id]: modeId};
  text(lane, 'Colors / ' + modeNames[mode], 20, 16, {size: 20, weight: 700, color: TEXT});
  colors.forEach((c, i) => {
    const ry = 64 + i * 34;
    const chip = box(lane, c.name, 20, ry, 48, 24, c.name, 'RECTANGLE');
    ink(chip, 'strokes', LINE);
    text(lane, c.name, 84, ry + 4, {color: TEXT, size: 12});
    text(lane, show(c.values[mode]), 270, ry + 4, {color: SUB, size: 12});
    text(lane, c.source, 560, ry + 4, {color: SUB, size: 11});
  });
  tx += 800;
});
const groups = Map.groupBy(variables.filter((v) => v.type !== 'COLOR'), (v) => v.name.split(' / ')[0]);
let gx = tx, gy = 0;
for (const [group, entries] of groups) {
  const board = box(tokensPage, group, gx, gy, 640, 72 + entries.length * 26, SURFACE);
  board.variableModes = {[collection.id]: modeIds[0]};
  text(board, group, 20, 16, {size: 20, weight: 700, color: TEXT});
  entries.forEach((v, i) => {
    const ry = 60 + i * 26;
    text(board, v.name.split(' / ').slice(1).join(' / '), 20, ry, {color: TEXT, size: 12});
    text(board, String(v.values[0]), 280, ry, {color: SUB, size: 12});
    text(board, v.source, 360, ry, {color: SUB, size: 11});
  });
  gy += board.height + 24;
  if (gy > 1100) { gx += 680; gy = 0; }
}

// Components page: one board per component or state, the main component at its implemented state.
let cy = 0, cx = 0, rowHeight = 0;
for (const [name, source, note] of components) {
  const board = box(componentsPage, name, cx, cy, 10, 10, SURFACE);
  board.variableModes = {[collection.id]: modeIds[0]};
  text(board, name, 20, 16, {size: 16, weight: 700, color: TEXT});
  const caption = text(board, source + ' · ' + note, 20, 42, {color: SUB, size: 11});
  const master = box(board, name, 20, 76, 10, 10, null, 'COMPONENT');
  drawComponent(name, master, {g, box, text, ink, measure});
  board.width = Math.max(master.width + 40, caption.width + 40, 360);
  board.height = master.height + 100;
  rowHeight = Math.max(rowHeight, board.height);
  cx += board.width + 40;
  if (cx > 1800) { cx = 0; cy += rowHeight + 40; rowHeight = 0; }
}

for (const page of g.getPages().slice(1)) versionLabel(page);

const saved = await new IORegistry(BUILTIN_IO_FORMATS).writeDocument('fig', g);
const destination = path.resolve(process.argv[2] || path.join(dir, 'template.fig'));
const pending = fs.mkdtempSync(path.join(path.dirname(destination), '.template-'));
try { const next = path.join(pending, 'template.fig'); fs.writeFileSync(next, saved.data); fs.renameSync(next, destination); } finally { fs.rmdirSync(pending); }
console.log(JSON.stringify({file: path.relative(process.cwd(), destination), pages: g.getPages().map((p) => p.name), schemes, variables: g.variables.size, components: components.length, nodes: g.nodes.size, bytes: saved.data.length}));

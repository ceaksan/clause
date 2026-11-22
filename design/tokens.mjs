import fs from 'node:fs';

const root = new URL('../', import.meta.url);
export const read = (file) => fs.readFileSync(new URL(file, root), 'utf8');

const front = read('DESIGN.md').split('\n---\n')[0];
export const meta = Object.fromEntries(
  [...front.matchAll(/^(\w+): (.+)$/gm)].map(([, k, v]) => [k, v.split(' #')[0].trim()]),
);
export const designColors = Object.fromEntries(
  [...front.matchAll(/^  ([\w-]+): \{ value: "([^"]+)", hex: "(#[\dA-F]+)" \}/gm)].map(([, k, value, hex]) => [k, {value, hex}]),
);
export const schemes = meta.schemes.replace(/[[\]]/g, '').split(',').map((s) => s.trim());
export const modeNames = schemes.map((s) => s[0].toUpperCase() + s.slice(1));

const V = 'ClauseApp/Views/';
const lineOf = (file, line) => read(file).split('\n')[line - 1] ?? '';

// Every SwiftUI or AppKit color literal on a line, in order; a ternary inside Color(white:) yields both values.
export function colorLiterals(code) {
  const found = [];
  for (const m of code.matchAll(/NSColor\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+), alpha: ([\d.]+)\)|Color\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\)|Color\(white: ([^)]+)\)|Color\.white\b/g)) {
    if (m[1]) found.push(m[0]);
    else if (m[5]) found.push(m[0]);
    else if (m[8]) for (const n of m[8].match(/\d*\.?\d+/g)) found.push(`Color(white: ${n})`);
    else found.push('Color.white');
  }
  return found;
}
export function rgba(literal) {
  if (literal === 'Color.white') return {r: 1, g: 1, b: 1, a: 1};
  const n = literal.match(/\d*\.?\d+/g).map(Number);
  if (literal.startsWith('Color(white:')) return {r: n[0], g: n[0], b: n[0], a: 1};
  return {r: n[0], g: n[1], b: n[2], a: n[3] ?? 1};
}
export const hex = (literal) => {
  const c = rgba(literal);
  return '#' + ['r', 'g', 'b'].map((k) => Math.round(c[k] * 255).toString(16).padStart(2, '0')).join('').toUpperCase() + (c.a < 1 ? Math.round(c.a * 255).toString(16).toUpperCase() : '');
};

// [token, file, line, index of the literal on that line]
const colorSpecs = [
  ['window-bg', 'ClauseApp/ClauseApp.swift', 47, 0],
  ['title-bar-bg', V + 'ContentView.swift', 98, 0],
  ['board-bg', V + 'ContentView.swift', 48, 0],
  ['memo-editor-bg', V + 'NoteRowView.swift', 219, 0],
  ['row-bg', V + 'NoteRowView.swift', 93, 1],
  ['input-bg', V + 'InputBar.swift', 16, 0],
  ['row-bg-hover', V + 'NoteRowView.swift', 93, 0],
  ['memo-bg', V + 'NoteRowView.swift', 204, 0],
  ['divider', V + 'ContentView.swift', 34, 0],
  ['type-button-bg', V + 'InputBar.swift', 41, 1],
  ['line', V + 'InputBar.swift', 19, 0],
  ['type-button-bg-selected', V + 'InputBar.swift', 41, 0],
  ['text-empty', V + 'ContentView.swift', 203, 0],
  ['text-counter', V + 'NoteRowView.swift', 224, 0],
  ['icon-trash-header', V + 'ContentView.swift', 151, 0],
  ['text-meta', V + 'NoteRowView.swift', 179, 0],
  ['text-closed', V + 'NoteRowView.swift', 72, 0],
  ['type-button-fg', V + 'InputBar.swift', 38, 1],
  ['icon-action', V + 'NoteRowView.swift', 175, 0],
  ['text-pane', V + 'ContentView.swift', 167, 0],
  ['text-memo', V + 'NoteRowView.swift', 186, 0],
  ['text-title', V + 'ContentView.swift', 80, 0],
  ['ref-copied', V + 'NoteRowView.swift', 141, 0],
  ['icon-pinned', V + 'ContentView.swift', 91, 0],
  ['text-body', V + 'NoteRowView.swift', 72, 1],
  ['text-workspace', V + 'ContentView.swift', 134, 0],
  ['type-button-fg-selected', V + 'InputBar.swift', 38, 0],
  ['sent', V + 'NoteRowView.swift', 5, 0],
  ['decided', V + 'NoteRowView.swift', 6, 0],
  ['note', V + 'NoteRowView.swift', 7, 0],
  ['todo', V + 'NoteRowView.swift', 8, 0],
  ['warning', V + 'NoteRowView.swift', 9, 0],
];
export const colors = colorSpecs.map(([name, file, line, index]) => {
  const literal = colorLiterals(lineOf(file, line))[index];
  if (!literal) throw new Error(`${name}: no color literal ${index} at ${file}:${line}`);
  return {name, type: 'COLOR', values: [literal], source: `${file}:${line}`};
});

// [variable, file, line, pattern whose first group is the value]
const N = V + 'NoteRowView.swift', C = V + 'ContentView.swift', I = V + 'InputBar.swift';
const opacity = /\.opacity\(([\d.]+)\)/, ternaryOpacity = /\.opacity\([^?]+\? ([\d.]+) : 1\)/, idleOpacity = /\.opacity\(hovering \? 1 : ([\d.]+)\)/;
const size = /size: (\d+)/, h = /\.padding\(\.horizontal, (\d+)\)/, v = /\.padding\(\.vertical, (\d+)\)/, gap = /spacing: (\d+)/, radius = /cornerRadius: (\d+)|\.cornerRadius\((\d+)\)/;
const numberSpecs = [
  ['Opacity / open-decision-fill', N, 93, opacity], ['Opacity / open-pill-fill', C, 195, opacity], ['Opacity / error-bar-fill', C, 30, opacity],
  ['Opacity / open-decision-stroke', N, 97, opacity], ['Opacity / memo-editor-stroke', N, 220, opacity], ['Opacity / memo-rail', N, 206, opacity],
  ['Opacity / todo-done-marker', N, 110, ternaryOpacity], ['Opacity / decided-stamp', N, 152, opacity], ['Opacity / decided-marker', N, 116, opacity],
  ['Opacity / row-actions-idle', N, 176, idleOpacity], ['Opacity / memo-actions-idle', N, 200, idleOpacity],
  ['Type / title', C, 79, size], ['Type / workspace', C, 133, size], ['Type / pane', C, 166, size], ['Type / pane-id', C, 170, size],
  ['Type / workspace-subtitle', C, 139, size], ['Type / note-text', N, 71, size], ['Type / note-line-spacing', N, 74, /\.lineSpacing\((\d+)\)/],
  ['Type / note-line-limit', N, 75, /\.lineLimit\((\d+)\)/], ['Type / meta', N, 178, size], ['Type / memo', N, 185, size],
  ['Type / memo-line-spacing', N, 187, /\.lineSpacing\((\d+)\)/], ['Type / memo-counter', N, 223, size], ['Type / memo-buttons', N, 234, size],
  ['Type / input', I, 13, size], ['Type / type-button', I, 37, size], ['Type / open-pill', C, 191, size], ['Type / error-bar', C, 22, size],
  ['Type / empty', C, 202, size], ['Type / icon-row-action', N, 174, size], ['Type / icon-memo-action', N, 198, size], ['Type / icon-marker', N, 109, size],
  ['Type / icon-marker-warning', N, 123, size], ['Type / icon-pane', C, 164, size], ['Type / icon-ref-copy', N, 139, size], ['Type / icon-pin', C, 90, size],
  ['Radius / row', N, 92, radius], ['Radius / input', I, 18, radius], ['Radius / memo', N, 204, radius], ['Radius / memo-editor', N, 219, radius], ['Radius / type-button', I, 42, radius],
  ['Spacing / title-bar horizontal', C, 96, h], ['Spacing / title-bar vertical', C, 97, v], ['Spacing / title-bar gap', C, 77, gap],
  ['Spacing / error-bar horizontal', C, 28, h], ['Spacing / error-bar vertical', C, 29, v], ['Spacing / error-bar gap', C, 18, gap],
  ['Spacing / board horizontal', C, 125, h], ['Spacing / board vertical', C, 126, v], ['Spacing / board group gap', C, 103, gap],
  ['Spacing / workspace stack', C, 112, gap], ['Spacing / you stack', C, 105, gap], ['Spacing / workspace-header horizontal', C, 157, h], ['Spacing / workspace-header gap', C, 131, gap],
  ['Spacing / pane stack', C, 161, gap], ['Spacing / pane header gap', C, 162, gap], ['Spacing / pane header leading', C, 174, /\.padding\(\.leading, (\d+)\)/], ['Spacing / pane header bottom', C, 175, /\.padding\(\.bottom, (\d+)\)/],
  ['Spacing / pane content indent', C, 179, /\.padding\(\.leading, (\d+)\)/], ['Spacing / pane rail inset', C, 184, v], ['Spacing / pane rail offset', C, 186, /\.padding\(\.leading, (\d+)\)/],
  ['Spacing / row vertical', N, 89, v], ['Spacing / row horizontal', N, 90, h], ['Spacing / row marker gap', N, 63, gap], ['Spacing / row stack', N, 69, gap],
  ['Spacing / meta gap', N, 133, gap], ['Spacing / ref gap', N, 136, gap], ['Spacing / row actions gap', N, 157, gap],
  ['Spacing / memo vertical', N, 202, v], ['Spacing / memo horizontal', N, 203, h], ['Spacing / memo top', N, 209, /\.padding\(\.top, (\d+)\)/], ['Spacing / memo gap', N, 183, gap], ['Spacing / memo actions gap', N, 191, gap],
  ['Spacing / memo editor stack', N, 213, gap], ['Spacing / memo editor padding', N, 217, /\.padding\((\d+)\)/], ['Spacing / memo editor buttons gap', N, 221, gap],
  ['Spacing / input-bar horizontal', I, 30, h], ['Spacing / input-bar vertical', I, 31, v], ['Spacing / input-bar gap', I, 10, gap],
  ['Spacing / input-field horizontal', I, 14, h], ['Spacing / input-field vertical', I, 15, v],
  ['Spacing / type-button horizontal', I, 39, h], ['Spacing / type-button vertical', I, 40, v], ['Spacing / type-button gap', I, 24, gap],
  ['Spacing / open-pill horizontal', C, 193, h], ['Spacing / open-pill vertical', C, 194, v],
  ['Size / window default width', 'ClauseApp/ClauseApp.swift', 29, /width: (\d+)/], ['Size / window default height', 'ClauseApp/ClauseApp.swift', 29, /height: (\d+)/],
  ['Size / window min width', 'ClauseApp/ClauseApp.swift', 48, /width: (\d+)/], ['Size / window min height', 'ClauseApp/ClauseApp.swift', 48, /height: (\d+)/],
  ['Size / marker width', N, 65, /width: (\d+)/], ['Size / marker height', N, 65, /height: (\d+)/], ['Size / note dot', N, 128, /width: (\d+)/],
  ['Size / pane rail width', C, 183, /width: (\d+)/], ['Size / memo rail width', N, 206, /width: (\d+)/],
  ['Size / memo editor min height', N, 218, /minHeight: (\d+)/], ['Size / memo editor max height', N, 218, /maxHeight: (\d+)/],
  ['Size / border width', I, 19, /lineWidth: (\d+)/], ['Size / open decision border', N, 97, /lineWidth: (\d+)/], ['Size / memo editor border', N, 220, /lineWidth: (\d+)/],
  ['Motion / ref copied feedback (s)', N, 249, /seconds\(([\d.]+)\)/],
];
export const numbers = numberSpecs.map(([name, file, line, pattern]) => {
  const m = lineOf(file, line).match(pattern);
  if (!m) throw new Error(`${name}: ${pattern} not found at ${file}:${line}`);
  return {name, type: 'FLOAT', values: [Number(m[1] ?? m[2])], source: `${file}:${line}`, pattern};
});
export const variables = [...colors, ...numbers];
export const num = (name) => numbers.find((n) => n.name === name).values[0];

export const components = [
  ['Title bar / pinned', `${C}:76`, 'pin.fill at icon-pinned; window floating (default)'],
  ['Title bar / unpinned', `${C}:76`, 'pin.slash at text-empty after toggling'],
  ['Open pill', `${C}:189`, '"N open" 10pt semibold sent on sent capsule at 0.14'],
  ['Error bar', `${C}:17`, 'exclamationmark.triangle.fill in warning, 11pt text-body, warning fill at 0.18'],
  ['Workspace header', `${C}:130`, 'title 13pt bold, monospaced subtitle, open pill, trash'],
  ['Workspace header / You', `${C}:106`, 'user group: no subtitle, pill or trash'],
  ['Pane header', `${C}:160`, 'terminal icon, label 11pt semibold, monospaced pane id'],
  ['Marker / note', `${N}:125`, '6pt circle in note'],
  ['Marker / todo', `${N}:106`, 'square, 12pt, todo'],
  ['Marker / done todo', `${N}:106`, 'checkmark.square.fill, todo at 0.5'],
  ['Marker / warning', `${N}:121`, 'exclamationmark.triangle.fill, 11pt, warning'],
  ['Marker / decision sent', `${N}:117`, 'circle.dotted, 12pt bold, sent'],
  ['Marker / decision decided', `${N}:113`, 'checkmark.circle.fill, decided at 0.75'],
  ['Note row / note', `${N}:62`, 'row-bg, 13pt regular text-body, actions at 0.35'],
  ['Note row / note hover', `${N}:62`, 'row-bg-hover, actions at full opacity'],
  ['Note row / done todo', `${N}:62`, 'text-closed with strikethrough'],
  ['Note row / decision sent', `${N}:62`, 'sent fill 0.07 and stroke 0.22, 13pt medium'],
  ['Note row / decision decided', `${N}:62`, 'text-closed, "decided <time>" stamp in decided at 0.6'],
  ['Memo', `${N}:182`, '12pt text-memo on memo-bg, 2pt sent rail at 0.5'],
  ['Memo editor', `${N}:212`, 'memo-editor-bg, sent stroke at 0.4, counter; TextEditor text and Cancel/Save are system controls'],
  ['Input field', `${I}:11`, 'input-bg, 1pt line stroke, radius 6; placeholder uses system color'],
  ['Type button / selected', `${I}:34`, 'white on 0.25, 10pt medium monospaced'],
  ['Type button / unselected', `${I}:34`, '0.53 on 0.17'],
  ['Empty state', `${C}:198`, '"No notes yet" 13pt text-empty'],
];
export const componentNames = components.map((c) => c[0]);

export const sources = ['DESIGN.md', ...[...front.split('\nsource:\n')[1].matchAll(/^  - (\S+)/gm)].map((m) => m[1]), 'design/tokens.mjs', 'design/components.mjs'];
export const pageIndex = [
  ['Cover', 'Release metadata, page index and source files'],
  ['Tokens', 'Dark colors from the view literals, opacities, type sizes, radii, spacing and sizes'],
  ['Components', 'Window parts and note row states from the SwiftUI views'],
];
export const coverFields = () => [
  ['Company', meta.company], ['Brand', meta.brand], ['Design version', meta.design_version],
  ['Product version', meta.product_version], ['Source commit', meta.source_commit], ['Updated', meta.updated],
  ['Status', meta.status], ['Color schemes', modeNames.join(', ')], ['Template', meta.template],
  ['Template level', '1 (Cover, Tokens, Components)'],
];
export const show = String;

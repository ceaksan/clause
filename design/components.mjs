// Main components drawn from the SwiftUI views in ClauseApp/Views/ (sizes in points, 1pt = 1px).
// Text uses SF Pro Text and SF Mono outlines; SF Symbols are shown as color-bound placeholder
// squares named after the symbol, because the glyphs are not available to OpenPencil.
// Sample copy (refs, times, labels) is placeholder; positions follow the stack spacing in the views.
import {num} from './tokens.mjs';

const SF = 'SF Pro Text', MONO = 'SF Mono';
const sp = (k) => num('Spacing / ' + k), ty = (k) => num('Type / ' + k), op = (k) => num('Opacity / ' + k);

function symbol(h, parent, name, x, y, size, color, alpha = 1) {
  const n = h.box(parent, 'SF Symbol ' + name, x, y, size, size, color, 'RECTANGLE', alpha);
  n.cornerRadius = 2;
  return n;
}
// A tinted layer behind content: .opacity(x) applies to the color only, so it gets its own node.
function tint(h, parent, name, w, ht, color, alpha, {stroke = 0, radius = 0} = {}) {
  const n = h.box(parent, name, 0, 0, w, ht, stroke ? null : color, 'RECTANGLE', alpha);
  if (stroke) h.ink(n, 'strokes', color, {weight: stroke});
  n.cornerRadius = radius;
  return n;
}
function marker(h, parent, kind, x, y) {
  const m = h.box(parent, 'Marker', x, y, num('Size / marker width'), num('Size / marker height'));
  const s = ty('icon-marker'), c = (size) => [(14 - size) / 2, (17 - size) / 2];
  if (kind === 'note') { const d = num('Size / note dot'); h.box(m, 'Circle', (14 - d) / 2, (17 - d) / 2, d, d, 'note', 'ELLIPSE'); }
  if (kind === 'todo') symbol(h, m, 'square', ...c(s), s, 'todo');
  if (kind === 'done todo') symbol(h, m, 'checkmark.square.fill', ...c(s), s, 'todo', op('todo-done-marker'));
  if (kind === 'warning') { const w = ty('icon-marker-warning'); symbol(h, m, 'exclamationmark.triangle.fill', ...c(w), w, 'warning'); }
  if (kind === 'decision sent') symbol(h, m, 'circle.dotted (bold)', ...c(s), s, 'sent');
  if (kind === 'decision decided') symbol(h, m, 'checkmark.circle.fill', ...c(s), s, 'decided', op('decided-marker'));
  return m;
}
const WINDOW = () => num('Size / window default width');
const ROW = () => WINDOW() - 2 * sp('board horizontal') - sp('pane rail offset') - sp('pane content indent');

function noteRow(h, m, {kind, text, ref, time, decided, hover = false, actions}) {
  const width = ROW(), pv = sp('row vertical'), ph = sp('row horizontal');
  m.width = width;
  m.cornerRadius = num('Radius / row');
  const layers = kind === 'decision sent' ? [
    tint(h, m, 'Open decision fill', width, 0, 'sent', op('open-decision-fill'), {radius: m.cornerRadius}),
    tint(h, m, 'Open decision stroke', width, 0, 'sent', op('open-decision-stroke'), {radius: m.cornerRadius, stroke: num('Size / open decision border')}),
  ] : [];
  if (!layers.length) h.ink(m, 'fills', hover ? 'row-bg-hover' : 'row-bg');
  marker(h, m, kind, ph, pv);
  const x = ph + num('Size / marker width') + sp('row marker gap'), closed = kind === 'done todo' || kind === 'decision decided';
  const body = h.text(m, text, x, pv, {font: SF, size: ty('note-text'), weight: kind === 'decision sent' ? 500 : 400, color: closed ? 'text-closed' : 'text-body', strike: kind === 'done todo'});
  const my = pv + body.height + sp('row stack');
  let mx = x;
  const refText = h.text(m, ref, mx, my, {font: MONO, size: ty('meta'), color: 'icon-action'});
  mx += refText.width + sp('ref gap');
  symbol(h, m, 'doc.on.doc', mx, my + 1.5, ty('icon-ref-copy'), 'icon-action');
  mx += ty('icon-ref-copy') + sp('meta gap');
  const stamp = h.text(m, time, mx, my, {font: MONO, size: ty('meta'), color: 'text-meta'});
  mx += stamp.width + sp('meta gap');
  if (decided) h.text(m, 'decided ' + decided, mx, my, {font: MONO, size: ty('meta'), color: 'decided', alpha: op('decided-stamp')});
  const size = ty('icon-row-action'), group = h.box(m, 'Row actions', 0, my + 1, 0, size);
  group.opacity = hover ? 1 : op('row-actions-idle');
  actions.forEach((name, i) => symbol(h, group, name, i * (size + sp('row actions gap')), 0, size, 'icon-action'));
  group.width = actions.length * size + (actions.length - 1) * sp('row actions gap');
  group.x = width - ph - group.width;
  m.height = my + refText.height + pv;
  for (const l of layers) l.height = m.height;
}

const draw = {
  'Title bar / pinned': (h, m) => titleBar(h, m, true),
  'Title bar / unpinned': (h, m) => titleBar(h, m, false),
  'Open pill'(h, m) {
    const capsule = tint(h, m, 'Capsule', 0, 0, 'sent', op('open-pill-fill'));
    const t = h.text(m, '2 open', sp('open-pill horizontal'), sp('open-pill vertical'), {font: SF, size: ty('open-pill'), weight: 600, color: 'sent'});
    m.width = capsule.width = t.width + 2 * sp('open-pill horizontal');
    m.height = capsule.height = t.height + 2 * sp('open-pill vertical');
    capsule.cornerRadius = m.height / 2;
  },
  'Error bar'(h, m) {
    const px = sp('error-bar horizontal'), py = sp('error-bar vertical'), icon = 13;
    m.width = WINDOW();
    const fill = tint(h, m, 'Error fill', m.width, 0, 'warning', op('error-bar-fill'));
    symbol(h, m, 'exclamationmark.triangle.fill (body size)', px, py + 1.5, icon, 'warning');
    const t = h.text(m, 'Board not saved: <reason>', px + icon + sp('error-bar gap'), py, {font: SF, size: ty('error-bar'), color: 'text-body'});
    m.height = fill.height = py * 2 + Math.max(16, t.height);
  },
  'Workspace header': (h, m) => workspaceHeader(h, m, 'my-project', '~/code/my-project', true),
  'Workspace header / You': (h, m) => workspaceHeader(h, m, 'You', null, false),
  'Pane header'(h, m) {
    let x = sp('pane header leading');
    symbol(h, m, 'terminal', x, 2, ty('icon-pane'), 'text-meta');
    x += ty('icon-pane') + sp('pane header gap');
    const label = h.text(m, 'agent', x, 0, {font: SF, size: ty('pane'), weight: 600, color: 'text-pane'});
    x += label.width + sp('pane header gap');
    const id = h.text(m, 'pane-id', x, 1, {font: MONO, size: ty('pane-id'), color: 'text-meta'});
    m.width = x + id.width; m.height = label.height + sp('pane header bottom');
  },
  'Marker / note': (h, m) => markerOnly(h, m, 'note'),
  'Marker / todo': (h, m) => markerOnly(h, m, 'todo'),
  'Marker / done todo': (h, m) => markerOnly(h, m, 'done todo'),
  'Marker / warning': (h, m) => markerOnly(h, m, 'warning'),
  'Marker / decision sent': (h, m) => markerOnly(h, m, 'decision sent'),
  'Marker / decision decided': (h, m) => markerOnly(h, m, 'decision decided'),
  'Note row / note': (h, m) => noteRow(h, m, {kind: 'note', text: 'Note text', ref: 'N-1', time: '10:52', actions: ['trash']}),
  'Note row / note hover': (h, m) => noteRow(h, m, {kind: 'note', text: 'Note text', ref: 'N-1', time: '10:52', hover: true, actions: ['trash']}),
  'Note row / done todo': (h, m) => noteRow(h, m, {kind: 'done todo', text: 'Todo text', ref: 'T-2', time: '10:52', actions: ['trash']}),
  'Note row / decision sent': (h, m) => noteRow(h, m, {kind: 'decision sent', text: 'Decision headline', ref: 'D-3', time: '10:52', actions: ['square.and.pencil', 'checkmark.circle', 'trash']}),
  'Note row / decision decided': (h, m) => noteRow(h, m, {kind: 'decision decided', text: 'Decision headline', ref: 'D-3', time: '10:52', decided: '11:05', actions: ['square.and.pencil', 'arrow.uturn.backward.circle', 'trash']}),
  Memo(h, m) {
    const width = ROW() - sp('row horizontal') * 2 - num('Size / marker width') - sp('row marker gap');
    const pv = sp('memo vertical'), ph = sp('memo horizontal');
    m.width = width; m.cornerRadius = num('Radius / memo'); m.clipsContent = true;
    h.ink(m, 'fills', 'memo-bg');
    const t = h.text(m, 'Private memo', ph, pv, {font: SF, size: ty('memo'), color: 'text-memo'});
    m.height = t.height + 2 * pv;
    h.box(m, 'Rail', 0, 0, num('Size / memo rail width'), m.height, 'sent', 'RECTANGLE', op('memo-rail'));
    const size = ty('icon-memo-action'), group = h.box(m, 'Memo actions', width - ph - (2 * size + sp('memo actions gap')), pv + 2, 2 * size + sp('memo actions gap'), size);
    group.opacity = op('memo-actions-idle');
    symbol(h, group, 'pencil', 0, 0, size, 'text-closed');
    symbol(h, group, 'trash', size + sp('memo actions gap'), 0, size, 'text-closed');
  },
  'Memo editor'(h, m) {
    const width = ROW() - sp('row horizontal') * 2 - num('Size / marker width') - sp('row marker gap');
    const editor = h.box(m, 'TextEditor (system text)', 0, 0, width, num('Size / memo editor min height'), 'memo-editor-bg');
    editor.cornerRadius = num('Radius / memo-editor');
    tint(h, m, 'Editor stroke', width, editor.height, 'sent', op('memo-editor-stroke'), {stroke: num('Size / memo editor border'), radius: editor.cornerRadius});
    const counter = h.text(m, '0/1000', 0, editor.height + sp('memo editor stack'), {font: MONO, size: ty('memo-counter'), color: 'text-counter'});
    m.width = width; m.height = counter.y + counter.height;
  },
  'Input field'(h, m) {
    const button = (label) => h.measure(label, MONO, ty('type-button'), 500) + 2 * sp('type-button horizontal');
    const buttons = ['N', 'T', 'W'].reduce((w, l) => w + button(l), 0) + 2 * sp('type-button gap');
    m.width = WINDOW() - 2 * sp('input-bar horizontal') - sp('input-bar gap') - buttons;
    m.height = 2 * sp('input-field vertical') + 16;
    m.cornerRadius = num('Radius / input');
    h.ink(m, 'fills', 'input-bg');
    h.ink(m, 'strokes', 'line', {weight: num('Size / border width')});
  },
  'Type button / selected': (h, m) => typeButton(h, m, 'N', true),
  'Type button / unselected': (h, m) => typeButton(h, m, 'T', false),
  'Empty state'(h, m) {
    const t = h.text(m, 'No notes yet', 0, 0, {font: SF, size: ty('empty'), color: 'text-empty'});
    m.width = t.width; m.height = t.height;
  },
};

function titleBar(h, m, pinned) {
  const px = sp('title-bar horizontal'), py = sp('title-bar vertical');
  m.width = WINDOW();
  h.ink(m, 'fills', 'title-bar-bg');
  const t = h.text(m, 'Clause', px, py, {font: SF, size: ty('title'), weight: 600, color: 'text-title'});
  m.height = t.height + 2 * py;
  const size = ty('icon-pin');
  symbol(h, m, pinned ? 'pin.fill' : 'pin.slash', m.width - px - size, (m.height - size) / 2, size, pinned ? 'icon-pinned' : 'text-empty');
}
function workspaceHeader(h, m, title, subtitle, withActions) {
  const px = sp('workspace-header horizontal'), gap = sp('workspace-header gap');
  m.width = WINDOW() - 2 * sp('board horizontal');
  const t = h.text(m, title, px, 0, {font: SF, size: ty('workspace'), weight: 700, color: 'text-workspace'});
  if (subtitle) h.text(m, subtitle, px + t.width + gap, 3, {font: MONO, size: ty('workspace-subtitle'), color: 'text-meta'});
  m.height = t.height;
  if (!withActions) return;
  const size = ty('icon-row-action');
  symbol(h, m, 'trash', m.width - px - size, 3, size, 'icon-trash-header');
  const label = h.text(m, '2 open', 0, 0, {font: SF, size: ty('open-pill'), weight: 600, color: 'sent'});
  const pw = label.width + 2 * sp('open-pill horizontal'), ph = label.height + 2 * sp('open-pill vertical');
  const frame = h.box(m, 'Open pill', m.width - px - size - gap - pw, (m.height - ph) / 2, pw, ph);
  tint(h, frame, 'Capsule', pw, ph, 'sent', op('open-pill-fill'), {radius: ph / 2});
  h.g.reparentNode(label.id, frame.id);
  label.x = sp('open-pill horizontal'); label.y = sp('open-pill vertical');
}
function markerOnly(h, m, kind) {
  marker(h, m, kind, 0, 0);
  m.width = num('Size / marker width'); m.height = num('Size / marker height');
}
function typeButton(h, m, label, selected) {
  const t = h.text(m, label, sp('type-button horizontal'), sp('type-button vertical'), {font: MONO, size: ty('type-button'), weight: 500, color: selected ? 'type-button-fg-selected' : 'type-button-fg'});
  m.width = t.width - 1 + 2 * sp('type-button horizontal'); m.height = t.height + 2 * sp('type-button vertical');
  m.cornerRadius = num('Radius / type-button');
  h.ink(m, 'fills', selected ? 'type-button-bg-selected' : 'type-button-bg');
}

export function drawComponent(name, master, helpers) {
  if (!draw[name]) throw new Error('No drawing for component ' + name);
  draw[name](helpers, master);
}

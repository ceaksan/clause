import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {IORegistry, BUILTIN_IO_FORMATS} from '@open-pencil/core/io';
import {populateAllFigPages} from '@open-pencil/core/io/formats/fig';
import {meta, modeNames, variables, colors, designColors, componentNames, coverFields, pageIndex, rgba, read, colorLiterals, hex} from './tokens.mjs';

const dir = path.dirname(fileURLToPath(import.meta.url));
const file = path.resolve(process.argv[2] || path.join(dir, 'template.fig'));
const pkgPath = fileURLToPath(import.meta.resolve('@open-pencil/cli/package.json'));
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
assert.equal(pkg.version, '0.16.0', 'pinned @open-pencil/cli');
const cliBin = path.join(path.dirname(pkgPath), pkg.bin.openpencil);
const cli = (...args) => JSON.parse(execFileSync(process.execPath, [cliBin, ...args, file, '--json'], {encoding: 'utf8'}));

// Every token value must come from the source line it cites.
for (const v of variables) {
  const [src, line] = v.source.split(':');
  const code = read(src).split('\n')[Number(line) - 1];
  const ok = v.type === 'COLOR' ? colorLiterals(code).includes(v.values[0]) : Number(code.match(v.pattern)?.slice(1).find(Boolean)) === v.values[0];
  assert(ok, `${v.name} = ${v.values[0]} not found at ${v.source}`);
}
assert.equal(Object.keys(designColors).length, colors.length, 'DESIGN.md color count');
for (const c of colors) {
  const d = designColors[c.name];
  assert(d, 'DESIGN.md lacks color ' + c.name);
  assert.equal(d.value, c.values[0], 'DESIGN.md value ' + c.name);
  assert.equal(d.hex, hex(c.values[0]), 'DESIGN.md hex ' + c.name);
}
const opacities = [1, ...variables.filter((v) => v.name.startsWith('Opacity / ')).map((v) => v.values[0])];

const bytes = fs.readFileSync(file);
const {graph: g} = await new IORegistry(BUILTIN_IO_FORMATS).readDocument({name: 'template.fig', data: new Uint8Array(bytes)});
populateAllFigPages(g);
const pages = g.getPages(), pageNames = pages.map((p) => p.name);
assert.deepEqual(pageNames, pageIndex.map((p) => p[0]), 'page order');
assert.equal(cli('info').pages, pages.length);
const [cover, tokensPage, componentsPage] = pages;
const children = (n) => g.getChildren(n.id), desc = (n) => [n, ...children(n).flatMap(desc)];
const child = (n, name) => { const c = children(n).find((x) => x.name === name); assert(c, `${n.name} / ${name}`); return c; };
const texts = (n) => desc(n).filter((x) => x.type === 'TEXT');

const card = child(cover, 'Cover'), coverTexts = texts(card);
assert(coverTexts.some((t) => t.text === meta.name), 'cover title');
for (const [label, value] of coverFields()) {
  const k = coverTexts.find((t) => t.text === label);
  assert(k, 'cover field ' + label);
  assert(coverTexts.some((t) => t.y === k.y && t.x === 240 && t.text === value), `cover ${label} = ${value}`);
}
for (const p of pages) assert(coverTexts.some((t) => t.text === p.name && t.styleRuns?.[0]?.style.hyperlink?.value === p.id), 'page index link ' + p.name);

assert.equal(g.variableCollections.size, 1, 'one collection');
const [collection] = g.variableCollections.values();
assert.equal(collection.name, meta.name);
assert.deepEqual(collection.modes.map((m) => m.name), modeNames, 'modes');
const cliVars = cli('variables').collections;
assert.deepEqual(cliVars.map((c) => [c.name, c.modes, c.variables.length]), [[meta.name, modeNames, variables.length]]);
const byName = new Map([...g.variables.values()].map((v) => [v.name, v]));
assert.equal(byName.size, variables.length, 'variable count');
const near = (a, b) => ['r', 'g', 'b', 'a'].every((k) => Math.abs(a[k] - b[k]) <= 1 / 255 + 1e-5);
for (const spec of variables) {
  const v = byName.get(spec.name);
  assert(v, 'variable ' + spec.name);
  assert.equal(v.type, spec.type, spec.name);
  collection.modes.forEach((m, i) => {
    const actual = v.valuesByMode[m.modeId];
    if (spec.type === 'COLOR') assert(near(actual, rgba(spec.values[i])), `${spec.name} ${m.name}`);
    else if (spec.type === 'FLOAT') assert(Math.abs(actual - spec.values[i]) <= 1e-5 * Math.max(1, Math.abs(spec.values[i])), `${spec.name} ${m.name}: ${actual}`);
    else assert.equal(actual, spec.values[i], `${spec.name} ${m.name}`);
  });
}
collection.modes.forEach((m) => {
  const lane = child(tokensPage, 'Colors / ' + m.name);
  assert.equal(lane.variableModes[collection.id], m.modeId, 'lane mode ' + m.name);
  for (const c of colors) assert.equal(child(lane, c.name).boundVariables['fills/0/color'], byName.get(c.name).id, 'swatch ' + c.name);
});

for (const p of pages.slice(1)) {
  const band = child(p, 'Version label'), [t] = texts(band);
  assert.equal(t.text, `${meta.name} · design ${meta.design_version} · product ${meta.product_version} · ${p.name}`);
  for (const n of [band, t]) assert(g.variables.has(n.boundVariables['fills/0/color']), 'label bound on ' + p.name);
}

const masters = desc(componentsPage).filter((n) => n.type === 'COMPONENT');
assert.deepEqual(masters.map((m) => m.name).sort(), [...componentNames].sort(), 'components');
const ids = new Set([...g.variables.keys()]);
let bindings = 0, instances = 0, glyphTexts = 0;
for (const master of masters) {
  const paints = desc(master).flatMap((n) => ['fills', 'strokes'].flatMap((f) => (n[f] || []).map((paint, i) => [n, f, i, paint])));
  const solid = paints.filter(([, , , p]) => p.type === 'SOLID');
  assert(solid.length, 'no paint in ' + master.name);
  for (const [n, f, i, paint] of solid) {
    const id = n.boundVariables[`${f}/${i}/color`];
    assert(id && ids.has(id), `unbound ${f} on ${master.name} / ${n.name}`);
    const value = g.variables.get(id).valuesByMode[collection.modes[0].modeId];
    assert(near({...paint.color, a: value.a}, value), `${master.name} / ${n.name} paint differs from ${g.variables.get(id).name}`);
    assert(Math.abs(paint.opacity - value.a) < 1e-4, `${master.name} / ${n.name} paint opacity ${paint.opacity}`);
    bindings++;
  }
  for (const n of desc(master)) assert(opacities.some((o) => Math.abs(n.opacity - o) < 1e-4), `${master.name} / ${n.name} opacity ${n.opacity} is not a token opacity`);
  for (const t of texts(master)) assert(t.derivedTextGlyphs?.length, `${master.name} / ${t.name} has no glyph outlines`);
  glyphTexts += texts(master).length;
}
for (const inst of desc(componentsPage).filter((n) => n.type === 'INSTANCE')) {
  assert(masters.some((m) => m.id === inst.componentId), 'instance without main ' + inst.name);
  assert(inst.variableModes[collection.id], 'instance mode ' + inst.name);
  instances++;
}

console.log(JSON.stringify({file: path.basename(file), pages: pageNames, collection: collection.name, modes: modeNames, variables: byName.size, colors: colors.length, components: masters.length, componentColorBindings: bindings, componentTextsWithGlyphs: glyphTexts, modeInstances: instances, bytes: bytes.length}));

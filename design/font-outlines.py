"""Glyph outlines and advances for the macOS system fonts used by the template.

OpenPencil cannot load SF Pro or SF Mono by family name, so generate-template.mjs stores
pre-rendered glyph outlines (derivedTextGlyphs) on every text node that uses them.
Prints JSON: {"<family><weight>": {"<char>": [advance_em, base64_commands]}}.
"""

import base64
import json
import struct
from pathlib import Path

from fontTools.pens.basePen import BasePen
from fontTools.ttLib import TTFont

LETTERS = sorted({chr(k) for k in range(32, 127)} | set("·…"))
FONTS = Path("/System/Library/Fonts")
FACES = {
    "SF Pro Text": ("SFNS.ttf", (400, 500, 600, 700), {"opsz": 17}),
    "SF Mono": ("SFNSMono.ttf", (400, 500), {}),
}


class Outline(BasePen):
    def __init__(self, glyphs, units):
        super().__init__(glyphs)
        self.data = bytearray()
        self.units = units

    def points(self, op, *points):
        self.data.append(op)
        for x, y in points:
            self.data.extend(struct.pack("<ff", x / self.units, y / self.units))

    def _moveTo(self, xy):
        self.points(1, xy)

    def _lineTo(self, xy):
        self.points(2, xy)

    def _curveToOne(self, a, b, c):
        self.points(4, a, b, c)

    def _closePath(self):
        self.data.append(0)


faces = {}
for family, (file, weights, axes) in FACES.items():
    font = TTFont(FONTS / file)
    units = font["head"].unitsPerEm
    cmap = font.getBestCmap()
    for weight in weights:
        glyphs = font.getGlyphSet(location={**axes, "wght": weight})
        face = {}
        for ch in LETTERS:
            name = cmap.get(ord(ch))
            if not name:
                continue
            pen = Outline(glyphs, units)
            glyphs[name].draw(pen)
            face[ch] = [
                glyphs[name].width / units,
                base64.b64encode(pen.data or b"\x00").decode(),
            ]
        faces[family + str(weight)] = face
print(json.dumps(faces))

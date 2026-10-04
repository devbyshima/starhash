#!/usr/bin/env python3
# Writes StarHash's empty-state doodles into the asset catalog, one image
# set each with a light and a dark SVG, so iOS picks the one for the
# appearance. Hand-drawn in the style of the owner's reference: rounded
# lines 7 wide, flat fills, a hand in a dark cuff holding the subject, and
# a few strokes that say "look here".
#
#   python3 scripts/make_doodles.py
#
# Colours are the palette's: lines in the near black (light) or the pale
# grey (dark); paper in the sheets' near-white blue (light) or a lifted
# card grey (dark); fills a lighter blue (light) or the blue (dark).
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "StarHash", "Resources", "Assets.xcassets")

LIGHT = dict(L="#171717", P="#E8F6FE", F="#8FD3FA")
DARK = dict(L="#F4F4F4", P="#2A2A2A", F="#05A9F4")

# Each doodle's canvas trimmed to what is drawn on it, 6 points round,
# measured from a render: an empty state centres the image, so the drawing
# itself sits in the middle rather than a canvas with room left at its top.
# (Redraw one and measure it again.)
VIEWBOX = {
    "EmptyTransactions": (34, 24, 310, 376),
    "EmptyPeriod": (34, 24, 310, 376),
    "EmptySearch": (34, 24, 310, 376),
    "EmptyResults": (84, 22, 290, 329),
    "EmptyMatches": (34, 24, 310, 376),
    "EmptyCodes": (76, 18, 302, 310),
}


def head(name):
    x, y, w, h = VIEWBOX[name]
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" width="{w}" height="{h}">\n'

OPEN = '<g stroke="{L}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" fill="none">\n'

ATTENTION = '''
<path d="M268 62 C 272 50 276 42 281 34"/>
<path d="M296 78 C 306 70 314 64 323 58"/>
<path d="M304 108 C 314 107 324 107 334 108"/>
'''

HAND = '''
<path d="M44 392 C 58 360 74 332 92 306 C 112 312 132 324 150 340 C 138 362 124 382 112 398 Z" fill="{L}"/>
<path d="M96 304 C 104 280 122 262 146 256 C 160 252 172 254 182 260
         C 196 262 200 276 188 282 C 200 286 202 300 188 304
         C 198 310 196 322 182 324 C 188 332 182 344 168 342
         C 158 352 142 350 132 342 C 118 332 104 318 96 304 Z" fill="{F}"/>
<path d="M146 256 C 150 240 162 228 176 226 C 186 226 190 236 182 244 C 176 250 168 254 160 258" fill="{F}"/>
<path d="M168 284 C 174 284 178 283 182 282" stroke-width="5"/>
<path d="M166 306 C 172 306 177 305 182 304" stroke-width="5"/>
'''

DOODLES = {}

# Activity, nothing at all: a hand holding up a near-blank receipt.
DOODLES["EmptyTransactions"] = ATTENTION + '''
<g transform="rotate(-9 215 185)">
  <path d="M150 74 C 186 70 228 70 262 76 C 266 140 266 210 262 286
           L 250 274 L 238 288 L 226 274 L 214 288 L 202 274 L 190 288 L 178 274 L 166 288 L 156 276
           C 152 210 150 140 150 74 Z" fill="{P}"/>
  <path d="M172 108 C 184 102 196 112 208 106 C 220 100 232 110 242 106"/>
  <path d="M172 134 C 182 129 192 138 202 133 C 210 129 216 136 222 133"/>
  <path d="M172 172 L 244 172" stroke-dasharray="2 12"/>
  <path d="M196 208 C 206 202 216 212 226 206 C 232 202 238 208 244 205"/>
</g>
''' + HAND

# Activity, an empty period: a hand holding a calendar page, nothing marked.
DOODLES["EmptyPeriod"] = ATTENTION + '''
<g transform="rotate(-9 215 185)">
  <path d="M148 92 C 186 88 228 88 264 92 C 268 160 268 220 264 290 C 226 294 188 294 154 290 C 150 220 148 160 148 92 Z" fill="{P}"/>
  <path d="M148 92 C 186 88 228 88 264 92 C 265 104 265 116 265 126 C 226 129 188 129 149 126 C 148 116 148 104 148 92 Z" fill="{F}"/>
  <path d="M180 100 C 176 84 182 72 190 74 C 197 76 196 90 192 104"/>
  <path d="M228 100 C 224 84 230 72 238 74 C 245 76 244 90 240 104"/>
  <path d="M172 154 C 182 149 192 158 202 153 C 212 148 222 157 232 152 C 238 149 242 153 246 151"/>
  <g stroke-width="10">
    <path d="M176 188 L 176 188"/><path d="M200 188 L 200 188"/><path d="M224 188 L 224 188"/><path d="M248 188 L 248 188"/>
    <path d="M176 214 L 176 214"/><path d="M200 214 L 200 214"/><path d="M224 214 L 224 214"/><path d="M248 214 L 248 214"/>
    <path d="M200 240 L 200 240"/><path d="M224 240 L 224 240"/><path d="M248 240 L 248 240"/>
  </g>
</g>
''' + HAND

# Search, nothing typed yet: a hand holding up a magnifying glass.
DOODLES["EmptySearch"] = ATTENTION + '''
<path d="M196 214 L 152 268" stroke-width="26"/>
<path d="M196 214 L 152 268" stroke="{F}" stroke-width="12"/>
<circle cx="236" cy="168" r="64" fill="{P}"/>
<circle cx="236" cy="168" r="64" stroke-width="12"/>
<path d="M196 152 C 200 138 210 128 224 124"/>
''' + HAND

# Search, no results: a magnifying glass with a wobbly question mark in it.
DOODLES["EmptyResults"] = '''
<path d="M300 60 C 304 48 308 40 313 32"/>
<path d="M326 78 C 336 70 344 64 353 58"/>
<path d="M334 108 C 344 107 354 107 364 108"/>
<path d="M232 252 L 300 330" stroke-width="30"/>
<path d="M232 252 L 300 330" stroke="{F}" stroke-width="16"/>
<circle cx="182" cy="186" r="86" fill="{P}"/>
<circle cx="182" cy="186" r="86" stroke-width="12"/>
<path d="M130 160 C 134 140 148 124 168 118" stroke-width="6"/>
<path d="M160 168 C 158 146 178 136 194 142 C 212 148 214 170 198 178 C 186 184 182 192 184 206"/>
<path d="M185 232 L 185 232" stroke-width="13"/>
'''

# Picker, no matches: a hand holding a phone, a number being typed.
DOODLES["EmptyMatches"] = ATTENTION + '''
<g transform="rotate(-9 215 185)">
  <rect x="150" y="62" width="112" height="226" rx="20" fill="{F}"/>
  <rect x="162" y="80" width="88" height="186" rx="10" fill="{P}" stroke-width="5"/>
  <path d="M174 104 C 182 98 190 108 198 103 C 206 98 214 108 222 103 C 228 100 232 104 236 102" stroke-width="6"/>
  <g stroke-width="11">
    <path d="M180 138 L 180 138"/><path d="M206 138 L 206 138"/><path d="M232 138 L 232 138"/>
    <path d="M180 164 L 180 164"/><path d="M206 164 L 206 164"/><path d="M232 164 L 232 164"/>
    <path d="M180 190 L 180 190"/><path d="M206 190 L 206 190"/><path d="M232 190 L 232 190"/>
    <path d="M206 216 L 206 216"/>
  </g>
  <path d="M196 274 L 216 274" stroke-width="5"/>
</g>
''' + HAND

# Buy, no codes: a card with a big hand-drawn # and a + badge at its corner.
DOODLES["EmptyCodes"] = '''
<path d="M302 56 C 306 44 310 36 315 28"/>
<path d="M330 76 C 340 68 348 62 357 56"/>
<path d="M338 106 C 348 105 358 105 368 106"/>
<g transform="rotate(7 200 200)">
  <path d="M94 118 C 160 112 240 112 306 118 C 312 180 312 250 306 306 C 240 312 160 312 98 306 C 90 250 90 180 94 118 Z" fill="{P}"/>
  <path d="M170 150 C 166 196 160 240 154 280" stroke-width="13"/>
  <path d="M234 150 C 230 196 224 240 218 280" stroke-width="13"/>
  <path d="M136 186 C 176 182 222 182 266 186" stroke-width="13"/>
  <path d="M130 244 C 170 240 216 240 260 244" stroke-width="13"/>
</g>
<circle cx="300" cy="126" r="40" fill="{F}"/>
<path d="M300 106 L 300 146" stroke-width="9"/>
<path d="M280 126 L 320 126" stroke-width="9"/>
'''

def svg(name, body, palette):
    return head(name) + OPEN.format(**palette) + body.format(**palette) + "</g>\n</svg>\n"


def main():
    for name, body in DOODLES.items():
        folder = os.path.join(ASSETS, f"{name}.imageset")
        os.makedirs(folder, exist_ok=True)
        for mode, palette in (("light", LIGHT), ("dark", DARK)):
            with open(os.path.join(folder, f"{name}-{mode}.svg"), "w") as f:
                f.write(svg(name, body, palette))
        contents = {
            "images": [
                {"filename": f"{name}-light.svg", "idiom": "universal"},
                {
                    "appearances": [{"appearance": "luminosity", "value": "dark"}],
                    "filename": f"{name}-dark.svg",
                    "idiom": "universal",
                },
            ],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True, "template-rendering-intent": "original"},
        }
        with open(os.path.join(folder, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
        print(folder)


main()

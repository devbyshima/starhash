#!/usr/bin/env python3
# Writes StarHash's empty-state doodles into the asset catalog, one image
# set each with a light and a dark SVG, so iOS picks the one for the
# appearance. Drawn after the owner's reference, GO Club's illustrations:
#
#   python3 scripts/make_doodles.py
#
# - Three tones on the page and nothing else, no white and no black: a
#   deep navy for lines and dark fills, a light periwinkle for the subject,
#   both measured from the reference on its blue, which is StarHash's.
# - Fills are flat, hand-cut blobs with soft edges and no outline
#   (blob()). Lines are a brush pen (line()): round ends, a little uneven
#   in width, thin for the drawing and the same width at any scale.
# - Hands are outlines with the page showing through, filled with the
#   page's own colour so they cover what they hold, in a navy sleeve; a
#   loose cord with a loop in it trails off, and a few short strokes say
#   "look here".
# - Dark mode has no reference, so it keeps the drawing in the near
#   black's terms: the subject stays periwinkle and the details on it
#   navy, the dark fills turn the blue, and lines straight on the page the
#   lifted blue (brandBlueLift), so every line still reads.
#
# Every point is placed here, so each canvas is trimmed to the drawing,
# 6 points round: an empty state centres the image, and room left on one
# side would push the drawing off centre. The wobble is seeded from each
# shape's own points, so running this again writes the same files.
import json
import math
import os
import random
import zlib
from contextlib import contextmanager

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "StarHash", "Resources", "Assets.xcassets")

# page: the ground, which fills hands. fill: the subject. dark: sleeves,
# shadows, the dark half of a thing. line: lines straight on the page.
# ink: lines drawn on the subject. chalk: lines drawn on a dark fill.
LIGHT = dict(page="#3020FE", fill="#5982EF", dark="#140A95", line="#140A95", ink="#140A95", chalk="#5982EF")
DARK = dict(page="#171717", fill="#5982EF", dark="#3020FE", line="#8A80FF", ink="#140A95", chalk="#5982EF")

PEN = 4.6
MARGIN = 6


def _mul(m, n):
    a, b, c, d, e, f = m
    a2, b2, c2, d2, e2, f2 = n
    return (a * a2 + c * b2, b * a2 + d * b2, a * c2 + c * d2, b * c2 + d * d2, a * e2 + c * f2 + e, b * e2 + d * f2 + f)


def _apply(m, p):
    a, b, c, d, e, f = m
    return (a * p[0] + c * p[1] + e, b * p[0] + d * p[1] + f)


def _rotation(deg, cx, cy):
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    return (c, s, -s, c, cx - c * cx + s * cy, cy - s * cx - c * cy)


def _seed(*parts):
    return zlib.crc32(repr(parts).encode())


def _noise(rng, scales=((58, 0.6), (24, 0.3), (11, 0.1))):
    waves = [(2 * math.pi / l, rng.uniform(0, 2 * math.pi), a) for l, a in scales]
    return lambda s: sum(a * math.sin(k * s + p) for k, p, a in waves)


def _catmull(pts, closed):
    """Centripetal Catmull-Rom through the points, sampled densely."""
    if len(pts) < 2:
        return list(pts)
    P = ([pts[-1]] + pts + [pts[0], pts[1]]) if closed else ([pts[0]] + pts + [pts[-1]])
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]

        def tj(ti, a, b):
            d = math.hypot(b[0] - a[0], b[1] - a[1]) ** 0.5
            return ti + max(d, 1e-4)

        t0 = 0.0
        t1 = tj(t0, p0, p1)
        t2 = tj(t1, p1, p2)
        t3 = tj(t2, p2, p3)
        n = max(4, int(math.hypot(p2[0] - p1[0], p2[1] - p1[1]) / 1.5))
        for k in range(n):
            t = t1 + (t2 - t1) * k / n

            def lerp(a, b, ta, tb):
                if tb - ta < 1e-9:
                    return a
                u = (t - ta) / (tb - ta)
                return (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)

            a1 = lerp(p0, p1, t0, t1)
            a2 = lerp(p1, p2, t1, t2)
            a3 = lerp(p2, p3, t2, t3)
            b1 = lerp(a1, a2, t0, t2)
            b2 = lerp(a2, a3, t1, t3)
            out.append(lerp(b1, b2, t1, t2))
    if not closed:
        out.append(pts[-1])
    return out


def _resample(pts, step, closed):
    if closed:
        pts = pts + [pts[0]]
    out = [pts[0]]
    carry = 0.0
    for a, b in zip(pts, pts[1:]):
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        if seg < 1e-9:
            continue
        pos = step - carry
        while pos <= seg:
            u = pos / seg
            out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u))
            pos += step
        carry = seg - (pos - step)
    if closed:
        if len(out) > 2 and math.hypot(out[-1][0] - out[0][0], out[-1][1] - out[0][1]) < step * 0.5:
            out.pop()
    elif math.hypot(out[-1][0] - pts[-1][0], out[-1][1] - pts[-1][1]) > step * 0.3:
        out.append(pts[-1])
    return out


def _normals(pts, closed):
    n = len(pts)
    out = []
    for i in range(n):
        if closed:
            a, b = pts[i - 1], pts[(i + 1) % n]
        else:
            a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dy) or 1
        out.append((-dy / l, dx / l))
    return out


def _d(pts):
    s = "M" + " ".join(f"{x:.1f} {y:.1f}" for x, y in pts[:1])
    s += "L" + " ".join(f"{x:.1f} {y:.1f}" for x, y in pts[1:])
    return s + "Z"


class Doodle:
    """One drawing: its shapes in order, each a filled path in a palette
    key, back to front."""

    def __init__(self):
        self.items = []
        self.m = (1, 0, 0, 1, 0, 0)

    @contextmanager
    def turned(self, deg, cx, cy):
        saved = self.m
        self.m = _mul(self.m, _rotation(deg, cx, cy))
        yield
        self.m = saved

    @contextmanager
    def at(self, cx, cy, deg=0, scale=1, flip=False):
        """Draw in a local frame: its origin at (cx, cy), turned by deg,
        scaled (lines keep their width) and mirrored if flip."""
        saved = self.m
        t = math.radians(deg)
        c, s = math.cos(t), math.sin(t)
        fx = -scale if flip else scale
        self.m = _mul(self.m, (c * fx, s * fx, -s * scale, c * scale, cx, cy))
        yield
        self.m = saved

    def _place(self, pts):
        return [_apply(self.m, p) for p in pts]

    def blob(self, key, pts, wobble=1.1):
        """A flat fill with a soft, hand-cut edge: rounded through its
        points, then nudged in and out a little along its length."""
        pts = self._place(pts)
        rng = random.Random(_seed(key, pts))
        dense = _resample(_catmull(pts, True), 2.4, True)
        nrm = _normals(dense, True)
        f = _noise(rng)
        out = [(p[0] + n[0] * wobble * f(i * 2.4), p[1] + n[1] * wobble * f(i * 2.4)) for i, (p, n) in enumerate(zip(dense, nrm))]
        self.items.append((key, _d(out), out))

    def line(self, key, pts, w=PEN, var=0.2, wobble=0.5):
        """A brush-pen stroke: round ends, its width swelling and thinning
        a little along the way."""
        pts = self._place(pts)
        rng = random.Random(_seed(key, pts, w))
        if len(pts) == 1:
            pts = [pts[0], (pts[0][0] + 0.01, pts[0][1])]
        dense = _resample(_catmull(pts, False), 1.6, False)
        if len(dense) < 2:
            dense = [pts[0], pts[-1]]
        nrm = _normals(dense, False)
        fw, fc = _noise(rng), _noise(rng)
        half, left, right = [], [], []
        for i, (p, n) in enumerate(zip(dense, nrm)):
            s = i * 1.6
            h = w / 2 * (1 + var * fw(s))
            o = wobble * fc(s)
            c = (p[0] + n[0] * o, p[1] + n[1] * o)
            left.append((c[0] + n[0] * h, c[1] + n[1] * h))
            right.append((c[0] - n[0] * h, c[1] - n[1] * h))
            half.append((c, n, h))

        def cap(c, n, h, sign):
            # half a circle from one side to the other, round the end
            base = math.atan2(n[1], n[0])
            return [(c[0] + h * math.cos(base - sign * math.pi * k / 8), c[1] + h * math.sin(base - sign * math.pi * k / 8)) for k in range(1, 8)]

        c0, n0, h0 = half[0]
        c1, n1, h1 = half[-1]
        out = left + cap(c1, n1, h1, 1) + right[::-1] + cap(c0, (-n0[0], -n0[1]), h0, 1)
        self.items.append((key, _d(out), out))

    def bounds(self):
        xs = [x for _, _, pts in self.items for x, _ in pts]
        ys = [y for _, _, pts in self.items for _, y in pts]
        return min(xs), min(ys), max(xs), max(ys)

    def svg(self, palette):
        x0, y0, x1, y1 = self.bounds()
        x, y = math.floor(x0 - MARGIN), math.floor(y0 - MARGIN)
        w, h = math.ceil(x1 + MARGIN) - x, math.ceil(y1 + MARGIN) - y
        body = "".join(f'<path fill="{palette[k]}" d="{d}"/>\n' for k, d, _ in self.items)
        return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" width="{w}" height="{h}">\n{body}</svg>\n'


def rrect(x, y, w, h, r, taper=0.0, skew=0.0):
    """A rounded rectangle's outline as points, for blob() to soften,
    pulled a little out of true as if drawn quickly: taper narrows its top
    (or its foot, when negative) and skew leans it."""
    pts = []
    corners = [(x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)]
    mx, my = x + w / 2, y + h / 2
    for cx, cy, a0 in corners:
        for k in range(4):
            a = math.radians(a0 + 90 * k / 3)
            px, py = cx + r * math.cos(a), cy + r * math.sin(a)
            f = 1 + taper * (py - my) / h
            pts.append((mx + (px - mx) * f + skew * (py - my), py))
    return pts


def receipt(x, y, w, h, teeth=8, depth=9):
    """A till receipt's outline: straight sides, a torn zigzag foot."""
    pts = [(x + 2, y + 2), (x + w / 2, y - 1), (x + w - 2, y + 1)]
    pts += [(x + w + 1, y + h * f) for f in (0.3, 0.6, 0.9)]
    step = w / teeth
    for i in range(teeth + 1):
        tx = x + w - i * step
        # each tip twice, so the spline keeps it a point
        pts += [(tx, y + h), (tx, y + h)]
        if i < teeth:
            pts += [(tx - step / 2, y + h - depth)]
    pts += [(x - 1, y + h * f) for f in (0.9, 0.6, 0.3)]
    return pts


DOODLES = {}


def doodle(fn):
    DOODLES[fn.__name__] = fn
    return fn


def ticks(d, cx, cy, start, r=(20, 38), lengths=(1, 1, 0.75, 0.2), spread=24):
    """Three or four short strokes radiating from a point: "look here"."""
    for i, f in enumerate(lengths):
        a = math.radians(start + i * spread)
        r0, r1 = r[0], r[0] + (r[1] - r[0]) * f
        d.line("line", [(cx + r0 * math.cos(a), cy + r0 * math.sin(a)), (cx + r1 * math.cos(a), cy + r1 * math.sin(a))], w=PEN * 0.9)


def disc(cx, cy, r, n=11, seed=0):
    """A circle's outline, a little out of round."""
    rng = random.Random(seed)
    return [(cx + r * (1 + rng.uniform(-0.03, 0.03)) * math.cos(2 * math.pi * k / n), cy + r * (1 + rng.uniform(-0.03, 0.03)) * math.sin(2 * math.pi * k / n)) for k in range(n)]


def cuff(d, y=0, w=48, h=36, lobes=2):
    """A sleeve's end in the dark fill, in an arm's frame (the arm points
    down from the hand): the side the wrist comes out of nearly straight,
    the far side scalloped."""
    pts = [(-w / 2, y + 1), (0, y - 1), (w / 2, y + 1), (w / 2 + 2, y + h * 0.5)]
    for i in range(lobes):
        x0 = w / 2 - i * w / lobes
        x1 = x0 - w / lobes
        if i:
            pts.append((x0, y + h - 4))
        pts += [(x0 - w / lobes * 0.2, y + h + 2), ((x0 + x1) / 2, y + h + 7), (x1 + w / lobes * 0.2, y + h + 2)]
    pts += [(-w / 2 - 2, y + h * 0.5)]
    d.blob("dark", pts, wobble=0.7)


def fist(d):
    """A fist round something running up from it, in its own frame: the
    thumb over the top, the knuckles down the right, the wrist going down
    into its sleeve. The page fills it, so it covers what it holds."""
    d.blob("page", [(-16, 50), (-21, 30), (-27, 10), (-28, -12), (-20, -25), (-4, -29), (8, -27), (13, -20),
                     (24, -15), (26, -4), (28, 5), (27, 14), (28, 22), (22, 32), (13, 36), (13, 50)], wobble=0.1)
    d.line("line", [(-16, 52), (-20, 30), (-27, 10), (-28, -12), (-20, -25), (-4, -29), (8, -27), (12, -20), (8, -14), (-6, -13)])
    d.line("line", [(13, -19), (23, -15), (25, -6), (17, -3), (3, -2)])
    d.line("line", [(19, -2), (28, 4), (26, 13), (17, 15), (1, 16)])
    d.line("line", [(19, 16), (27, 22), (22, 32), (13, 36), (13, 52)])
    cuff(d, 46, w=62, h=46)


def sleeve(d, w=80, h=46):
    """A rounder sleeve, in an arm's frame: its top, where the hand comes
    out, nearly flat with a notch or two, its far side a half moon."""
    pts = [(-w / 2, 3), (-w / 5, -2), (-w / 10, 5), (w / 10, -1), (w / 2, 2)]
    pts += [(w / 2 * math.cos(math.radians(a)), h * math.sin(math.radians(a))) for a in (25, 60, 95, 130, 160)]
    d.blob("dark", pts, wobble=0.7)


def grip(d, fingers=4, fw=15, reach=13):
    """Fingers curled over an edge, seen from the back of the hand, in a
    frame with the edge along y = 0 (what is held above it) and the arm
    going down into its sleeve. The page fills the hand, so it covers
    what it holds."""
    x0 = -fingers * fw / 2
    tops = [(x0 + fw * (i + 0.5), -reach + (3 if i == fingers - 1 else 1.5 if i == 0 else 0)) for i in range(fingers)]
    outline = [(x0 - 3, 34), (x0 - 1, -2)]
    for x, y in tops:
        outline += [(x - fw / 2 + 1, y + 6), (x, y), (x + fw / 2 - 1, y + 6)]
    outline += [(-x0 + 1, 0), (-x0 + 1, 34)]
    d.blob("page", outline + [(-x0 - 4, 50), (x0 + 4, 50)], wobble=0.1)
    for i, (x, y) in enumerate(tops):
        last = i == fingers - 1
        start = (x0 - 2, 36) if i == 0 else (x - fw / 2 + 1, y + 13)
        mid = [(x0 - 1, 8)] if i == 0 else []
        end = [(x + fw / 2, y + 12), (-x0 + 1, 36)] if last else [(x + fw / 2 - 1.5, y + 6)]
        d.line("line", [start] + mid + [(x - fw / 2 + 1, y + 5), (x - 2, y), (x + 3, y + 0.5)] + end)
    d.line("line", [(x0 + 10, 26), (x0 + 16, 30)])
    with d.at(0, 44):
        cuff(d, 0, w=fingers * fw + 8, h=38, lobes=3)


@doodle
def EmptyTransactions(d):
    ticks(d, 74, 44, 196)
    with d.turned(-12, 140, 120):
        d.blob("fill", receipt(84, 28, 112, 182), wobble=0.8)
        d.line("ink", [(102, 56), (111, 50), (120, 56), (129, 50), (138, 56), (146, 52)])
        d.line("ink", [(102, 78), (134, 77)])
        d.line("ink", [(104, 172), (124, 171)])
    # a right hand holding its edge, the arm going off down the right
    with d.at(206, 196, -36, 1.3):
        fist(d)
    d.line("line", [(222, 292), (200, 300), (180, 296), (176, 284), (186, 278), (192, 290), (180, 308), (148, 314), (114, 304), (94, 286)])


@doodle
def EmptyPeriod(d):
    ticks(d, 262, 46, -100)
    with d.turned(10, 180, 115):
        d.line("line", [(144, 44), (143, 26), (150, 18), (158, 24), (157, 44)])
        d.line("line", [(204, 44), (203, 26), (210, 18), (218, 24), (217, 44)])
        d.blob("fill", rrect(110, 40, 140, 150, 14, taper=-0.05))
        d.blob("dark", [(112, 44), (180, 39), (248, 43), (250, 74), (180, 77), (110, 74)])
        d.line("chalk", [(130, 58), (138, 54), (146, 59), (154, 55)])
        for y in (100, 124, 148):
            for x in (138, 166, 194, 222):
                d.line("ink", [(x - 1.5, y), (x + 1.5, y + 0.4)], w=6.2)
        for x in (194, 222):
            d.line("ink", [(x - 1.5, 172), (x + 1.5, 172.4)], w=6.2)
    # a left hand holding its corner, the arm going off down the left
    with d.at(128, 204, 40, 1.3, flip=True):
        fist(d)
    d.line("line", [(110, 284), (130, 294), (148, 292), (154, 280), (144, 274), (138, 286), (150, 304), (182, 310), (214, 298), (234, 280)])


@doodle
def EmptySearch(d):
    ticks(d, 270, 60, -104)
    d.blob("dark", [(176, 140), (188, 156), (128, 198), (116, 182)])
    d.blob("fill", disc(220, 108, 56, seed=3))
    d.blob("dark", [(274, 100), (268, 134), (248, 158), (220, 166), (192, 160), (208, 156), (234, 148), (254, 128), (264, 100)])
    d.line("ink", [(186, 106), (191, 88), (206, 75)])
    with d.at(118, 200, 54, 1.32):
        fist(d)
    d.line("line", [(76, 278), (96, 292), (114, 292), (122, 282), (114, 274), (106, 284), (116, 302), (150, 314), (190, 304), (218, 286)])


@doodle
def EmptyResults(d):
    ticks(d, 222, 64, -84, r=(22, 38))
    d.blob("dark", [(178, 176), (194, 162), (262, 222), (248, 240)])
    d.blob("fill", disc(136, 124, 78, seed=5))
    d.blob("dark", [(74, 88), (62, 126), (72, 166), (100, 196), (136, 204), (110, 194), (84, 166), (74, 128), (82, 94)])
    d.line("ink", [(112, 108), (116, 90), (132, 80), (152, 84), (160, 100), (152, 116), (138, 124), (136, 144)])
    d.line("ink", [(136, 166), (137, 168)], w=8)
    d.line("ink", [(162, 64), (182, 74), (194, 92)])
    d.line("line", [(256, 236), (262, 252), (256, 266), (242, 264), (240, 250), (252, 252), (250, 272), (226, 290), (186, 294), (150, 284)])


@doodle
def EmptyMatches(d):
    ticks(d, 244, 58, -100)
    with d.turned(14, 160, 140):
        # fingertips round the far edge, behind the phone
        for y, r in ((128, 10), (153, 11), (178, 10)):
            d.blob("page", [(200, y - r), (218, y - r - 1), (228, y), (218, y + r + 1), (200, y + r)], wobble=0.1)
            d.line("line", [(206, y - r), (218, y - r), (227, y), (218, y + r), (208, y + r)])
        d.blob("fill", rrect(108, 50, 104, 164, 22, taper=0.07, skew=-0.04))
        d.line("ink", [(148, 66), (171, 65)], w=5)
        d.line("ink", [(128, 92), (137, 86), (146, 93), (155, 87), (164, 93), (172, 88)])
        d.line("ink", [(186, 82), (187, 99)])
        for y in (122, 144, 166):
            for x in (138, 160, 182):
                d.line("ink", [(x - 1.5, y), (x + 1.5, y + 0.5)], w=6.2)
        d.line("ink", [(158.5, 188), (161.5, 188.5)], w=6.2)
        # the hand in front of the phone's lower corner, the thumb hooked
        # over it: the page fills it, so it takes a bite out of the phone
        d.blob("page", [(80, 250), (77, 204), (88, 180), (104, 165), (124, 155), (135, 164), (128, 175), (122, 179), (125, 195), (132, 208), (145, 222), (152, 250)], wobble=0.1)
        d.line("line", [(104, 166), (114, 160), (124, 156)])
        d.line("line", [(124, 156), (130, 159), (135, 165)])
        d.line("line", [(135, 165), (130, 171), (126, 175), (120, 178)])
        d.line("line", [(121, 182), (124, 195), (131, 207), (143, 220), (149, 234)])
        d.line("line", [(104, 166), (92, 173), (83, 189), (80, 206), (82, 220)])
        d.line("line", [(171, 214), (170, 228)])
        with d.at(116, 240, 10):
            sleeve(d, 104, 54)
            d.line("line", [(36, 34), (52, 42), (66, 38), (70, 26), (60, 22), (54, 32), (66, 44), (92, 50), (122, 46), (148, 32)])


@doodle
def EmptyCodes(d):
    ticks(d, 262, 44, -110)
    with d.turned(-8, 160, 150):
        d.blob("dark", rrect(88, 96, 170, 128, 18, skew=0.07))
        d.blob("fill", rrect(72, 78, 170, 128, 18, taper=-0.04, skew=0.05))
        # a tag's hole and its string, wandering off
        d.line("ink", [(92, 98), (93, 99)], w=9)
        d.line("line", [(86, 77), (80, 62), (66, 54), (54, 60), (58, 72), (70, 68), (66, 50), (52, 34), (30, 30)])
        for (a, b) in (((130, 104), (118, 186)), ((178, 104), (166, 186)), ((100, 128), (206, 126)), ((96, 162), (202, 160))):
            d.line("ink", [a, b], w=10)
    d.blob("dark", disc(240, 88, 30, seed=7))
    d.line("chalk", [(240, 74), (239, 102)], w=PEN * 1.2)
    d.line("chalk", [(226, 89), (254, 88)], w=PEN * 1.2)


def main():
    for name, fn in DOODLES.items():
        d = Doodle()
        fn(d)
        folder = os.path.join(ASSETS, f"{name}.imageset")
        os.makedirs(folder, exist_ok=True)
        for mode, palette in (("light", LIGHT), ("dark", DARK)):
            with open(os.path.join(folder, f"{name}-{mode}.svg"), "w") as f:
                f.write(d.svg(palette))
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


if __name__ == "__main__":
    main()

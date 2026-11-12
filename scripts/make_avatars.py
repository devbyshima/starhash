#!/usr/bin/env python3
# Fetches the silhouettes StarHash shows for a person with no photo: twelve
# of DiceBear's "Shadows" avatars (a bust in one ink, CC0 1.0), with no
# background and the ink black, into the asset catalog as template images,
# so the app draws them in its own colours (ShadowAvatar). The same seeds
# give the same drawings, so running it again changes nothing unless
# DiceBear's style does.
#
#   python3 scripts/make_avatars.py
#
# Output: StarHash/Resources/Assets.xcassets/Shadow01...Shadow12.imageset
import copy
import json
import os
import urllib.request
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "StarHash", "Resources", "Assets.xcassets")
COUNT = 12
URL = "https://api.dicebear.com/10.x/shadows/svg?seed=starhash-{}&inkColor=000000&backgroundColor=00000000"


SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)


def clean(svg: str) -> str:
    """The drawing alone, as plain paths: the metadata goes (the licence
    travels in the app's Licences page), and so do the see-through
    background, which a template would fill, and the `<use>` references
    and clip path, which Xcode's SVG renderer does not always follow."""
    root = ET.fromstring(svg)
    tag = lambda name: f"{{{SVG}}}{name}"
    defs = root.find(tag("defs"))
    shapes = {element.get("id"): element for element in (defs if defs is not None else []) if element.get("id")}

    def expand(element):
        for index, child in enumerate(list(element)):
            if child.tag == tag("use"):
                target = shapes[child.get("href").lstrip("#")]
                group = ET.Element(tag("g"))
                if child.get("transform"):
                    group.set("transform", child.get("transform"))
                for part in target:
                    group.append(copy.deepcopy(part))
                expand(group)
                element.remove(child)
                element.insert(index, group)
            else:
                expand(child)

    body = [child for child in root if child.tag == tag("g")]
    out = ET.Element(tag("svg"), {"viewBox": root.get("viewBox", "0 0 100 100")})
    for group in body:
        group.attrib.pop("clip-path", None)
        for rect in [r for r in group if r.tag == tag("rect")]:
            group.remove(rect)
        expand(group)
        out.append(group)
    return ET.tostring(out, encoding="unicode")


for index in range(1, COUNT + 1):
    request = urllib.request.Request(URL.format(index), headers={"User-Agent": "starhash-make-avatars"})
    with urllib.request.urlopen(request) as response:
        svg = clean(response.read().decode())
    name = f"Shadow{index:02d}"
    folder = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, f"{name}.svg"), "w") as f:
        f.write(svg)
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({
            "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
        }, f, indent=2)
        f.write("\n")
    print(folder)

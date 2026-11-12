#!/usr/bin/env python3
# Writes the "StarHash SMS" shortcut that auto-verify installs, already set
# up: one action, StarHash's Process Carrier SMS, fed the shortcut's input,
# and an automation for iOS 27 (when a message containing RWF arrives, run
# without asking). That automation never appeared on a real iPhone, so the
# guide has it made by hand; this one may be wrongly encoded. Then signs it with
# the Mac's `shortcuts sign` (needs this Mac signed in to iCloud), since
# iOS only imports signed shortcut files.
#
#   python3 scripts/make_shortcut.py
#   python3 scripts/make_shortcut.py --bundle-id com.fulltimestudio.starhash --out serein.shortcut
#
# Output: StarHash/Resources/StarHash SMS.shortcut, the file shared for
# StarHashShortcut.iCloudLinks (bundled only if the links are ever removed).
# The action names the app by bundle id and team, read from project.yml by
# default: Shortcuts only runs it, and only shows the app's icon for it,
# on an iPhone with that very app installed. A build under another id (the
# owner's own iPhone keeps an older one) needs a shortcut of its own, made
# with --bundle-id and shared under its own link. Regenerate after renaming
# the intent, the bundle id or the team.
import argparse
import os
import plistlib
import re
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def from_project(key: str) -> str:
    """The first value of `key` in project.yml: the app target's."""
    with open(os.path.join(ROOT, "project.yml")) as f:
        match = re.search(rf"^\s*{key}:\s*(\S+)", f.read(), re.M)
    return match.group(1).strip('"') if match else ""


parser = argparse.ArgumentParser()
parser.add_argument("--bundle-id", default=from_project("PRODUCT_BUNDLE_IDENTIFIER"))
parser.add_argument("--team", default=from_project("DEVELOPMENT_TEAM"))
parser.add_argument("--out", default=os.path.join(ROOT, "StarHash", "Resources", "StarHash SMS.shortcut"))
parser.add_argument("--icon", help="a PNG for the shortcut's icon, in place of Shortcuts' glyph")
args = parser.parse_args()

OUT = os.path.abspath(args.out)
BUNDLE_ID = args.bundle_id
TEAM_ID = args.team
INTENT = "ProcessCarrierSMSIntent"

action = {
    "WFWorkflowActionIdentifier": f"{BUNDLE_ID}.{INTENT}",
    "WFWorkflowActionParameters": {
        "AppIntentDescriptor": {
            "AppIntentIdentifier": INTENT,
            "BundleIdentifier": BUNDLE_ID,
            "Name": "StarHash",
            "TeamIdentifier": TEAM_ID,
        },
        # The intent's `message` parameter, set to Shortcut Input.
        "message": {
            "Value": {"attachmentsByRange": {"{0, 1}": {"Type": "ExtensionInput"}}, "string": "￼"},
            "WFSerializationType": "WFTextTokenString",
        },
        # And `sender`, set to Shortcut Input's Sender, so StarHash can tell
        # a look-alike from someone's own number from M-Money's own.
        "sender": {
            "Value": {
                "attachmentsByRange": {"{0, 1}": {
                    "Type": "ExtensionInput",
                    "Aggrandizements": [{"Type": "WFPropertyVariableAggrandizement", "PropertyName": "Sender"}],
                }},
                "string": "￼",
            },
            "WFSerializationType": "WFTextTokenString",
        },
    },
}

workflow = {
    "WFWorkflowClientVersion": "2607.0.2",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    # Shortcuts' own default glyph on black. Shortcuts shows the icon of its
    # one action's app in its place, but only while BUNDLE_ID and TEAM_ID
    # name the app installed on that iPhone: the link shared in October
    # named com.fulltimestudio.starhash under the old team 7WHQR6L96K, so
    # every iPhone showed this wand instead.
    "WFWorkflowIcon": {"WFWorkflowIconGlyphNumber": 59511, "WFWorkflowIconStartColor": 255},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowTypes": [],
    "WFWorkflowHasShortcutInputVariables": True,
    "WFWorkflowInputContentItemClasses": ["WFStringContentItem", "WFRichTextContentItem", "WFGenericFileContentItem"],
    "WFWorkflowOutputContentItemClasses": [],
    "WFWorkflowHasOutputFallback": False,
    "WFWorkflowActions": [action],
    # The automation, as Shortcuts writes it when one is added to a shortcut.
    "WFWorkflowTriggers": [{
        "WFTriggerIdentifier": "WFMessageTrigger",
        "WFTriggerUUID": "91027366-30A9-476F-9DAE-0D90A230E361",
        "WFTriggerSerializedParameters": {
            "WFMessageConditions": {
                "WFSerializationType": "WFContentPredicateTableTemplate",
                "Value": {
                    "WFActionParameterFilterPrefix": 1,
                    "WFContentPredicateBoundedDate": False,
                    "WFActionParameterFilterTemplates": [
                        {"Operator": 1, "Property": "Message", "Removable": False, "Values": {"Text": "RWF"}},
                    ],
                },
            },
        },
    }],
}

if args.icon == "none":
    del workflow["WFWorkflowIcon"]
elif args.icon:
    with open(args.icon, "rb") as f:
        workflow["WFWorkflowIcon"]["WFWorkflowIconImageData"] = f.read()

with tempfile.TemporaryDirectory() as folder:
    unsigned = os.path.join(folder, "StarHash SMS.shortcut")
    with open(unsigned, "wb") as f:
        plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
    subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", unsigned, "--output", OUT], check=True)
print(f"{OUT} ({BUNDLE_ID}, team {TEAM_ID})")

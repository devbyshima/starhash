#!/usr/bin/env python3
# Writes the "StarHash SMS" shortcut that auto-verify installs, already set
# up: one action, StarHash's Process Carrier SMS, fed the shortcut's input,
# and its automation built in (iOS 27): when a message containing RWF
# arrives (every M-Money and AirtelMoney message does), run without asking. Then signs it with
# the Mac's `shortcuts sign` (needs this Mac signed in to iCloud), since
# iOS only imports signed shortcut files.
#
#   python3 scripts/make_shortcut.py
#
# Output: StarHash/Resources/StarHash SMS.shortcut, the file shared for
# StarHashShortcut.iCloudLink (bundled only if the link is ever removed).
# Regenerate it after renaming the intent, the bundle id or the team.
import os
import plistlib
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "StarHash", "Resources", "StarHash SMS.shortcut")

BUNDLE_ID = "com.fulltimestudio.starhash"
TEAM_ID = "7WHQR6L96K"
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
    },
}

workflow = {
    "WFWorkflowClientVersion": "2607.0.2",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    # A hash glyph on a dark tile.
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

with tempfile.TemporaryDirectory() as folder:
    unsigned = os.path.join(folder, "StarHash SMS.shortcut")
    with open(unsigned, "wb") as f:
        plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
    subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", unsigned, "--output", OUT], check=True)
print(OUT)

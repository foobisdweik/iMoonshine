#!/usr/bin/env python3
import argparse
import plistlib
import uuid
from pathlib import Path


def token_attachment(output_uuid: str, output_name: str = "Unknown Action") -> dict:
    return {
        "Value": {
            "OutputUUID": output_uuid,
            "Type": "ActionOutput",
            "OutputName": output_name,
        },
        "WFSerializationType": "WFTextTokenAttachment",
    }


def token_string(output_uuid: str, output_name: str) -> dict:
    return {
        "Value": {
            "string": "\ufffc",
            "attachmentsByRange": {
                "{0, 1}": {
                    "OutputUUID": output_uuid,
                    "Type": "ActionOutput",
                    "OutputName": output_name,
                }
            },
        },
        "WFSerializationType": "WFTextTokenString",
    }


def build_shortcut(bundle_id: str, team_id: str, app_name: str, intent_id: str) -> dict:
    intent_uuid = str(uuid.uuid4()).upper()
    grouping_uuid = str(uuid.uuid4()).upper()
    clipboard_uuid = str(uuid.uuid4()).upper()
    combined_uuid = str(uuid.uuid4()).upper()
    notification_uuid = str(uuid.uuid4()).upper()
    endif_uuid = str(uuid.uuid4()).upper()

    intent_output = token_attachment(intent_uuid)
    combined_output = token_attachment(combined_uuid, "Combined Text")

    return {
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowIcon": {
            "WFWorkflowIconStartColor": -398082585,
            "WFWorkflowIconGlyphNumber": 61440,
        },
        "WFWorkflowClientVersion": "3607.0.2",
        "WFWorkflowName": "iMoonshine Action Button",
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowHasOutputFallback": False,
        "WFWorkflowActions": [
            {
                "WFWorkflowActionIdentifier": f"{bundle_id}.{intent_id}",
                "WFWorkflowActionParameters": {
                    "AppIntentDescriptor": {
                        "TeamIdentifier": team_id,
                        "BundleIdentifier": bundle_id,
                        "Name": app_name,
                        "AppIntentIdentifier": intent_id,
                    },
                    "UUID": intent_uuid,
                },
            },
            {
                "WFWorkflowActionIdentifier": "is.workflow.actions.conditional",
                "WFWorkflowActionParameters": {
                    "WFInput": intent_output,
                    "WFControlFlowMode": 0,
                    "WFConditionalActionString": "",
                    "GroupingIdentifier": grouping_uuid,
                    "WFCondition": 4,
                },
            },
            {
                "WFWorkflowActionIdentifier": "is.workflow.actions.conditional",
                "WFWorkflowActionParameters": {
                    "GroupingIdentifier": grouping_uuid,
                    "WFControlFlowMode": 1,
                },
            },
            {
                "WFWorkflowActionIdentifier": "is.workflow.actions.setclipboard",
                "WFWorkflowActionParameters": {
                    "WFLocalOnly": False,
                    "WFInput": intent_output,
                    "UUID": clipboard_uuid,
                },
            },
            {
                "WFWorkflowActionIdentifier": "is.workflow.actions.text.combine",
                "WFWorkflowActionParameters": {
                    "WFTextCustomSeparator": "",
                    "UUID": combined_uuid,
                    "WFTextSeparator": "Spaces",
                    "text": [
                        "Copied to Clipboard:",
                        token_string(intent_uuid, "Unknown Action"),
                    ],
                },
            },
            {
                "WFWorkflowActionIdentifier": "is.workflow.actions.notification",
                "WFWorkflowActionParameters": {
                    "WFInput": combined_output,
                    "WFNotificationActionBody": token_string(combined_uuid, "Combined Text"),
                    "UUID": notification_uuid,
                },
            },
            {
                "WFWorkflowActionIdentifier": "is.workflow.actions.conditional",
                "WFWorkflowActionParameters": {
                    "WFControlFlowMode": 2,
                    "GroupingIdentifier": grouping_uuid,
                    "UUID": endif_uuid,
                },
            },
        ],
        "WFWorkflowInputContentItemClasses": [
            "WFAppContentItem",
            "WFAppStoreAppContentItem",
            "WFArticleContentItem",
            "WFContactContentItem",
            "WFDateContentItem",
            "WFEmailAddressContentItem",
            "WFFolderContentItem",
            "WFGenericFileContentItem",
            "WFImageContentItem",
            "WFiTunesProductContentItem",
            "WFLocationContentItem",
            "WFDCMapsLinkContentItem",
            "WFAVAssetContentItem",
            "WFPDFContentItem",
            "WFPhoneNumberContentItem",
            "WFRichTextContentItem",
            "WFSafariWebPageContentItem",
            "WFStringContentItem",
            "WFURLContentItem",
        ],
        "WFWorkflowTypes": ["Watch"],
        "WFWorkflowImportQuestions": [],
        "WFQuickActionSurfaces": [],
        "WFWorkflowHasShortcutInputVariables": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-id", default="XTL-T7WW7538GC.com.foobisdweik.iMoonshine")
    parser.add_argument("--team-id", default="T7WW7538GC")
    parser.add_argument("--app-name", default="iMoonshine")
    parser.add_argument("--intent-id", default="ToggleRecordingIntent")
    parser.add_argument("output", nargs="?", default="Shortcuts/iMoonshine Action Button.shortcut")
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    workflow = build_shortcut(args.bundle_id, args.team_id, args.app_name, args.intent_id)
    output.write_bytes(plistlib.dumps(workflow, fmt=plistlib.FMT_BINARY, sort_keys=False))
    print(output)


if __name__ == "__main__":
    main()

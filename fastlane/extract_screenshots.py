#!/usr/bin/env python3
"""
extract_screenshots.py
Extracts XCTAttachment screenshots from an .xcresult bundle by following the
per-test summaryRef reference chain, and writes them to <output_dir>.

Usage: extract_screenshots.py <xcresult_path> <device_tag> <output_dir>
"""

import json, os, subprocess, sys

def xcresult_get(xcresult_path, ref_id=None):
    """Fetch JSON from xcresult, optionally for a specific ref_id."""
    cmd = ["xcrun", "xcresulttool", "get", "--legacy",
           "--path", xcresult_path, "--format", "json"]
    if ref_id:
        cmd += ["--id", ref_id]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0 or not result.stdout.strip():
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None

def find_values(obj, key, found=None):
    """Recursively collect all values for a given key in a JSON tree."""
    if found is None:
        found = []
    if isinstance(obj, dict):
        if key in obj:
            found.append(obj[key])
        for v in obj.values():
            find_values(v, key, found)
    elif isinstance(obj, list):
        for item in obj:
            find_values(item, key, found)
    return found

def find_nodes(obj, type_name, found=None):
    """Recursively collect all nodes of a given _type._name."""
    if found is None:
        found = []
    if isinstance(obj, dict):
        if obj.get("_type", {}).get("_name") == type_name:
            found.append(obj)
        for v in obj.values():
            find_nodes(v, type_name, found)
    elif isinstance(obj, list):
        for item in obj:
            find_nodes(item, type_name, found)
    return found

def main():
    if len(sys.argv) != 4:
        print("Usage: extract_screenshots.py <xcresult_path> <device_tag> <output_dir>")
        sys.exit(1)

    xcresult_path = sys.argv[1]
    device_tag    = sys.argv[2]
    output_dir    = sys.argv[3]

    # Step 1: Get top-level JSON and find the testsRef ID
    top = xcresult_get(xcresult_path)
    if not top:
        print(f"ERROR: Could not read xcresult at {xcresult_path}")
        sys.exit(1)

    actions = top.get("actions", {}).get("_values", [])
    tests_ref_id = None
    for action in actions:
        tests_ref_id = (action
                        .get("actionResult", {})
                        .get("testsRef", {})
                        .get("id", {})
                        .get("_value"))
        if tests_ref_id:
            break

    if not tests_ref_id:
        print("WARNING: No testsRef found in xcresult")
        return

    # Step 2: Fetch the test plan summaries and collect per-test summaryRef IDs
    plan_data = xcresult_get(xcresult_path, tests_ref_id)
    if not plan_data:
        print("WARNING: Could not read test plan summaries")
        return

    test_metas = find_nodes(plan_data, "ActionTestMetadata")
    summary_refs = []
    for meta in test_metas:
        name = meta.get("name", {}).get("_value", "unknown")
        ref_id = (meta.get("summaryRef", {})
                     .get("id", {})
                     .get("_value"))
        if ref_id:
            summary_refs.append((name, ref_id))

    if not summary_refs:
        print("WARNING: No per-test summaryRef found")
        return

    # Step 3: For each test summary, fetch and collect attachments
    all_attachments = []  # list of (attachment_name, ref_id)
    for test_name, summary_ref_id in summary_refs:
        summary = xcresult_get(xcresult_path, summary_ref_id)
        if not summary:
            continue
        attachments = find_nodes(summary, "ActionTestAttachment")
        for att in attachments:
            att_name = att.get("name", {}).get("_value", "")
            uti      = att.get("uniformTypeIdentifier", {}).get("_value", "")
            ref      = (att.get("payloadRef", {})
                           .get("id", {})
                           .get("_value", ""))
            if att_name and ref and uti == "public.png":
                all_attachments.append((att_name, ref))

    if not all_attachments:
        print(f"WARNING: No named PNG screenshots found in {xcresult_path}")
        return

    # Sort by attachment name so numbering is deterministic
    all_attachments.sort(key=lambda x: x[0])

    os.makedirs(output_dir, exist_ok=True)

    # Step 4: Export each attachment as a PNG
    for idx, (att_name, ref_id) in enumerate(all_attachments, start=1):
        num      = str(idx).zfill(2)
        out_path = os.path.join(output_dir, f"{device_tag}-screenshot-{num}.png")

        export = subprocess.run(
            ["xcrun", "xcresulttool", "export", "--legacy",
             "--path", xcresult_path,
             "--id", ref_id,
             "--output-path", out_path,
             "--type", "file"],
            capture_output=True
        )
        if export.returncode == 0:
            print(f"  ✓ {att_name} → {os.path.basename(out_path)}")
        else:
            print(f"  ✗ {att_name}: {export.stderr.decode().strip()}")

if __name__ == "__main__":
    main()

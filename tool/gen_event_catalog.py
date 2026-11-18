"""Writes functions/src/eventCatalog.json from the Dart category and icon lists.

The Cloud Function classifies against this file, so it must match the app.
Run after editing lib/model/event_category.dart or the curated icon groups:

    python3 tool/gen_event_catalog.py

test/model/event_catalog_sync_test.dart fails when the two drift.
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "benchmark"))
from build_prompt import load_options  # noqa: E402

root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
categories, icons, colors = load_options(root)
out = os.path.join(root, "functions", "src", "eventCatalog.json")
with open(out, "w") as f:
    json.dump({"categories": categories, "icons": icons, "colors": colors}, f, indent=2, sort_keys=False)
    f.write("\n")
print(f"wrote {len(categories)} categories, {len(icons)} icons and {len(colors)} colours to {os.path.relpath(out, root)}")

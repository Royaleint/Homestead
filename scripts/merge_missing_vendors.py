#!/usr/bin/env python3
"""
Merge Missing Vendors into VendorDatabase.lua

Inserts missing vendors while maintaining sorted NPC ID order.
"""

import re
from pathlib import Path

PROJECT_DIR = Path(__file__).parent.parent
DB_PATH = PROJECT_DIR / 'Data' / 'VendorDatabase.lua'
MISSING_PATH = PROJECT_DIR / 'missing_vendors.lua'

def parse_vendor_entry(content, start_pos):
    """Parse a single vendor entry from Lua content"""
    # Find the vendor ID
    id_match = re.search(r'\[(\d+)\]\s*=\s*\{', content[start_pos:])
    if not id_match:
        return None, start_pos

    npc_id = int(id_match.group(1))
    entry_start = start_pos + id_match.start()

    # Find the closing brace for this vendor
    brace_count = 0
    in_vendor = False
    i = entry_start
    while i < len(content):
        if content[i] == '{':
            brace_count += 1
            in_vendor = True
        elif content[i] == '}':
            brace_count -= 1
            if in_vendor and brace_count == 0:
                # Found the end of this vendor entry
                entry_end = i + 1
                # Include trailing comma and newlines
                while entry_end < len(content) and content[entry_end] in ',\n\t ':
                    entry_end += 1

                vendor_text = content[entry_start:entry_end]
                return {'id': npc_id, 'text': vendor_text}, entry_end
        i += 1

    return None, start_pos

def read_vendors_from_file(file_path):
    """Read all vendor entries from a Lua file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    vendors = []
    pos = 0
    while pos < len(content):
        vendor, pos = parse_vendor_entry(content, pos)
        if vendor:
            vendors.append(vendor)
        else:
            pos += 1

    return sorted(vendors, key=lambda v: v['id'])

def merge_vendors(existing_vendors, new_vendors):
    """Merge new vendors into existing list, maintaining sort order"""
    # Create a dict of existing IDs for quick lookup
    existing_ids = {v['id'] for v in existing_vendors}

    # Filter out vendors that already exist
    vendors_to_add = [v for v in new_vendors if v['id'] not in existing_ids]

    print(f"Existing vendors: {len(existing_vendors)}")
    print(f"New vendors to add: {len(vendors_to_add)}")

    if not vendors_to_add:
        print("No new vendors to add!")
        return existing_vendors

    # Merge and sort
    all_vendors = existing_vendors + vendors_to_add
    return sorted(all_vendors, key=lambda v: v['id'])

def generate_vendors_table(vendors):
    """Generate the complete VendorDatabase.Vendors table"""
    lines = []
    lines.append("VendorDatabase.Vendors = {")

    for vendor in vendors:
        # Remove leading/trailing whitespace from vendor text
        vendor_text = vendor['text'].strip()
        # Ensure proper indentation
        if not vendor_text.startswith('\t'):
            vendor_text = '\t' + vendor_text
        lines.append(vendor_text)

    lines.append("}")

    return '\n'.join(lines)

def update_database(vendors):
    """Update VendorDatabase.lua with merged vendors"""
    # Read the entire database file
    with open(DB_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the VendorDatabase.Vendors table
    vendors_match = re.search(
        r'(VendorDatabase\.Vendors\s*=\s*\{)(.+?)(^\})',
        content,
        re.DOTALL | re.MULTILINE
    )

    if not vendors_match:
        print("ERROR: Could not find VendorDatabase.Vendors table")
        return False

    # Generate new vendors table
    new_vendors_table = generate_vendors_table(vendors)

    # Replace the old table with the new one
    new_content = (
        content[:vendors_match.start()] +
        new_vendors_table +
        content[vendors_match.end():]
    )

    # Write back to file
    with open(DB_PATH, 'w', encoding='utf-8') as f:
        f.write(new_content)

    return True

def main():
    print("Reading existing VendorDatabase.lua...")
    existing_vendors = read_vendors_from_file(DB_PATH)

    print("\nReading missing vendors...")
    if not MISSING_PATH.exists():
        print(f"ERROR: {MISSING_PATH} not found")
        print("Run generate_missing_vendors.py first")
        return 1

    new_vendors = read_vendors_from_file(MISSING_PATH)

    print("\nMerging vendors...")
    merged_vendors = merge_vendors(existing_vendors, new_vendors)

    print("\nUpdating VendorDatabase.lua...")
    if update_database(merged_vendors):
        print(f"[OK] Successfully updated database")
        print(f"  Total vendors: {len(merged_vendors)}")
        print(f"  New vendors added: {len(merged_vendors) - len(existing_vendors)}")
    else:
        print("[FAIL] Failed to update database")
        return 1

    return 0

if __name__ == '__main__':
    exit(main())

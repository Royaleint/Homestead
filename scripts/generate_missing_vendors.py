#!/usr/bin/env python3
"""
Generate Missing Vendor Entries

Creates Lua code for vendors missing from our database,
converting coordinates from 0-100 format to 0-1 format.
"""

import re
from pathlib import Path

HOMEBOUND_PATH = Path(r'C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HomeBound\db.lua')

# Map IDs to expansion names
MAP_TO_EXPANSION = {
    # Classic
    17: "Classic",  # Blasted Lands
    25: "Classic",  # Hillsbrad
    36: "Classic",  # Burning Steppes
    87: "Classic",  # Ironforge
    218: "Cataclysm",  # Gilneas
    499: "Classic",  # Bizmo's Brawlpub
    500: "Classic",  # Bizmo's Brawlpub Alliance
    503: "Classic",  # Brawl'gar

    # TBC
    530: "TBC",
    539: "WOD",  # Frostfire/Shadowmoon

    # WotLK
    619: "Legion",  # Broken Shore / Dalaran
    626: "Legion",  # Dalaran
    627: "Legion",  # Dalaran
    628: "Legion",  # Dalaran
    630: "Legion",  # Azsuna

    # Legion
    641: "Legion",  # Val'sharah
    647: "Legion",  # Acherus
    680: "Legion",  # Suramar
    695: "Legion",  # Skyhold
    702: "Legion",  # Netherlight Temple
    709: "Legion",  # Wandering Isle
    717: "Legion",  # Dreadscar Rift
    720: "Legion",  # Fel Hammer
    726: "Cataclysm",  # Maelstrom
    735: "Legion",  # Hall of Guardian
    739: "Legion",  # Trueshot Lodge
    747: "Legion",  # Dreamgrove

    # BfA
    862: "BfA",  # Zuldazar
    895: "BfA",  # Tiragarde
    940: "Legion",  # Krokuun/Mac'Aree
    942: "BfA",  # Stormsong
    1161: "BfA",  # Boralus
    1164: "BfA",  # Dazar'alor
    1165: "BfA",  # Dazar'alor
    1186: "Classic",  # Blackrock Depths
    1473: "BfA",  # Chamber of Heart
    1530: "MOP",  # Vale instance

    # Dragonflight
    2022: "DF",  # Waking Shores
    2025: "DF",  # Thaldraszus
    2112: "DF",  # Valdrakken
    2151: "DF",  # Forbidden Reach

    # TWW
    2213: "TWW",  # Azj-Kahet (correct)
    2214: "TWW",  # Ringing Deeps
    2215: "TWW",  # Hallowfall
    2248: "TWW",  # Emerald Dream
    2339: "TWW",  # Dornogal
    2346: "TWW",  # Undermine
    2351: "TWW",  # Siren Isle
    2352: "TWW",  # Siren Isle
    2406: "TWW",  # Liberation of Undermine
    2472: "TWW",  # Tazavesh
}

# Missing vendors from comparison report
MISSING_VENDORS = [
    13217, 44337, 86779, 89939, 93971, 106901, 109306, 112634, 115736, 115805,
    142115, 152194, 189226, 191025, 193659, 199605, 209220, 216888, 240465,
    248525, 248594, 249684, 250820, 251042, 252043, 252345, 252498, 252605,
    252969, 253067, 253086, 253235, 253387, 253434, 253596, 253602, 255101,
    255203, 255213, 255216, 255218, 255221, 255222, 255228, 255230, 255278,
    255297, 255298, 255299, 255301, 255319, 255325, 255326, 256750, 256826,
    257897,
]

def parse_homebound_vendors():
    """Parse HomeBound vendor data"""
    print(f"Reading {HOMEBOUND_PATH}...")

    with open(HOMEBOUND_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find db.vendors table
    vendors_match = re.search(r'db\.vendors\s*=\s*\{(.+?)^\}',
                              content, re.DOTALL | re.MULTILINE)
    if not vendors_match:
        print("ERROR: Could not find db.vendors table")
        return {}

    vendors_content = vendors_match.group(1)

    # Pattern: { id = 12345, model3D = ..., title = "Name", x = ..., y = ..., mapID = ... }
    vendor_pattern = r'\{\s*id\s*=\s*(\d+)[^}]*title\s*=\s*"([^"]+)"[^}]*x\s*=\s*([0-9.]+)[^}]*y\s*=\s*([0-9.]+)[^}]*mapID\s*=\s*(\d+)'

    vendors = {}
    for match in re.finditer(vendor_pattern, vendors_content):
        npc_id = int(match.group(1))
        name = match.group(2)
        x = float(match.group(3))
        y = float(match.group(4))
        mapID = int(match.group(5))

        vendors[npc_id] = {
            'npcID': npc_id,
            'name': name,
            'x': x,
            'y': y,
            'mapID': mapID,
        }

    print(f"  Parsed {len(vendors)} vendors")
    return vendors

def generate_vendor_entries(vendors):
    """Generate Lua code for missing vendors"""
    lines = []
    lines.append("-- Missing vendors from HomeBound/DecorVendor")
    lines.append("-- Coordinates converted from 0-100 to 0-1 format")
    lines.append("")

    for npc_id in sorted(MISSING_VENDORS):
        if npc_id not in vendors:
            print(f"WARNING: Vendor {npc_id} not found in HomeBound data")
            continue

        vendor = vendors[npc_id]

        # Convert coordinates from 0-100 to 0-1
        x = vendor['x'] / 100.0
        y = vendor['y'] / 100.0
        mapID = vendor['mapID']
        name = vendor['name']

        # Determine expansion
        expansion = MAP_TO_EXPANSION.get(mapID, "Unknown")

        # Generate Lua entry
        lines.append(f"\t[{npc_id}] = {{")
        lines.append(f'\t\tname = "{name}",')
        lines.append(f"\t\tx = {x:.4f},")
        lines.append(f"\t\ty = {y:.4f},")
        lines.append(f"\t\tmapID = {mapID},")
        lines.append(f'\t\texpansion = "{expansion}",')
        lines.append(f"\t\titems = {{}},  -- TODO: Scan vendor in-game")
        lines.append("\t},")
        lines.append("")

    return '\n'.join(lines)

def main():
    vendors = parse_homebound_vendors()

    if not vendors:
        return 1

    lua_code = generate_vendor_entries(vendors)

    output_file = Path(__file__).parent.parent / 'missing_vendors.lua'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(lua_code)

    print(f"\nGenerated Lua code saved to: {output_file}")
    print(f"Total vendors: {len([v for v in MISSING_VENDORS if v in vendors])}")
    print("\nNext steps:")
    print("1. Review the generated file")
    print("2. Copy entries into Data/VendorDatabase.lua")
    print("3. Sort vendors by NPC ID")
    print("4. Test in-game")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Convert VendorDatabase.lua from array-based to NPC-keyed structure.

Usage: python convert_vendor_db.py
"""

import re
import sys
from pathlib import Path
from collections import defaultdict

# Expansion mapping
EXPANSION_MAP = {
    "TWW": "TWW",
    "Undermine": "TWW",
    "Karesh": "TWW",
    "Dragonflight": "DF",
    "Shadowlands": "SL",
    "BFA": "BFA",
    "WoD": "WoD",
    "MoP": "MoP",
    "WotLK": "WotLK",
    "Cataclysm": "Classic",  # Merge into Classic
    "Classic": "Classic",
    "OrderHalls": "Legion",
    "Neighborhoods": "TWW",
    "Events": "Events",
}

def parse_lua_file(filepath):
    """Read and return the Lua file content."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def extract_vendor_blocks(content):
    """Extract all vendor entry blocks from the Lua content."""
    vendors = []
    duplicates = []
    seen_npc_ids = {}

    # Find each expansion array
    expansion_pattern = r'VendorDatabase\.(\w+)\s*=\s*\{'

    for match in re.finditer(expansion_pattern, content):
        array_name = match.group(1)

        # Skip non-vendor arrays
        if array_name in ('ZoneToContinentMap', 'ContinentNames'):
            continue

        expansion = EXPANSION_MAP.get(array_name)
        if not expansion:
            print(f"Warning: Unknown array '{array_name}', skipping")
            continue

        # Find the content of this array
        start_pos = match.end()
        brace_count = 1
        pos = start_pos

        while brace_count > 0 and pos < len(content):
            if content[pos] == '{':
                brace_count += 1
            elif content[pos] == '}':
                brace_count -= 1
            pos += 1

        array_content = content[start_pos:pos-1]

        # Parse individual vendor entries
        vendor_entries = parse_vendor_entries(array_content, array_name, expansion)

        for vendor in vendor_entries:
            npc_id = vendor['npcID']
            if npc_id in seen_npc_ids:
                duplicates.append({
                    'npcID': npc_id,
                    'name': vendor.get('name', 'Unknown'),
                    'first_array': seen_npc_ids[npc_id],
                    'second_array': array_name,
                })
            else:
                seen_npc_ids[npc_id] = array_name
                vendors.append(vendor)

    return vendors, duplicates

def parse_vendor_entries(array_content, array_name, expansion):
    """Parse vendor entries from an array's content."""
    vendors = []

    # Match individual vendor blocks: { npcID = ..., ... },
    # This regex finds balanced braces for each vendor entry
    entry_pattern = r'\{\s*npcID\s*='

    pos = 0
    while True:
        match = re.search(entry_pattern, array_content[pos:])
        if not match:
            break

        entry_start = pos + match.start()

        # Find the matching closing brace
        brace_count = 1
        i = entry_start + 1
        while brace_count > 0 and i < len(array_content):
            if array_content[i] == '{':
                brace_count += 1
            elif array_content[i] == '}':
                brace_count -= 1
            i += 1

        entry_content = array_content[entry_start:i]
        vendor = parse_single_vendor(entry_content, array_name, expansion)
        if vendor:
            vendors.append(vendor)

        pos = i

    return vendors

def parse_single_vendor(entry_content, array_name, expansion):
    """Parse a single vendor entry block."""
    vendor = {'expansion': expansion, 'sourceArray': array_name}

    # Extract npcID
    npc_match = re.search(r'npcID\s*=\s*(\d+)', entry_content)
    if not npc_match:
        return None
    vendor['npcID'] = int(npc_match.group(1))

    # Extract name
    name_match = re.search(r'name\s*=\s*"([^"]*)"', entry_content)
    if name_match:
        vendor['name'] = name_match.group(1)

    # Extract mapID
    map_match = re.search(r'mapID\s*=\s*(\d+)', entry_content)
    if map_match:
        vendor['mapID'] = int(map_match.group(1))

    # Extract coords and flatten
    coords_match = re.search(r'coords\s*=\s*\{\s*x\s*=\s*([0-9.]+)\s*,\s*y\s*=\s*([0-9.]+)\s*\}', entry_content)
    if coords_match:
        vendor['x'] = float(coords_match.group(1))
        vendor['y'] = float(coords_match.group(2))

    # Extract and split zone
    zone_match = re.search(r'zone\s*=\s*"([^"]*)"', entry_content)
    if zone_match:
        zone_str = zone_match.group(1)
        if ' - ' in zone_str:
            parts = zone_str.split(' - ', 1)
            vendor['zone'] = parts[0]
            vendor['subzone'] = parts[1]
        else:
            vendor['zone'] = zone_str

    # Extract faction
    faction_match = re.search(r'faction\s*=\s*"([^"]*)"', entry_content)
    if faction_match:
        vendor['faction'] = faction_match.group(1)

    # Extract currency
    currency_match = re.search(r'currency\s*=\s*"([^"]*)"', entry_content)
    if currency_match:
        vendor['currency'] = currency_match.group(1)

    # Extract optional fields
    notes_match = re.search(r'notes\s*=\s*"([^"]*)"', entry_content)
    if notes_match:
        vendor['notes'] = notes_match.group(1)

    seasonal_match = re.search(r'seasonal\s*=\s*"([^"]*)"', entry_content)
    if seasonal_match:
        vendor['seasonal'] = seasonal_match.group(1)

    covenant_match = re.search(r'covenant\s*=\s*"([^"]*)"', entry_content)
    if covenant_match:
        vendor['covenant'] = covenant_match.group(1)

    class_match = re.search(r'class\s*=\s*"([^"]*)"', entry_content)
    if class_match:
        vendor['class'] = class_match.group(1)

    # Extract items - just the itemIDs
    items = []
    item_pattern = r'itemID\s*=\s*(\d+)'
    for item_match in re.finditer(item_pattern, entry_content):
        items.append(int(item_match.group(1)))
    vendor['items'] = items

    return vendor

def extract_zone_maps(content):
    """Extract ZoneToContinentMap and ContinentNames."""
    zone_map = {}
    continent_names = {}

    # Extract ZoneToContinentMap
    zone_match = re.search(r'VendorDatabase\.ZoneToContinentMap\s*=\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}', content, re.DOTALL)
    if zone_match:
        map_content = zone_match.group(1)
        for line_match in re.finditer(r'\[(\d+)\]\s*=\s*(\d+)', map_content):
            zone_map[int(line_match.group(1))] = int(line_match.group(2))

    # Extract ContinentNames
    names_match = re.search(r'VendorDatabase\.ContinentNames\s*=\s*\{([^}]+)\}', content, re.DOTALL)
    if names_match:
        names_content = names_match.group(1)
        for line_match in re.finditer(r'\[(\d+)\]\s*=\s*"([^"]*)"', names_content):
            continent_names[int(line_match.group(1))] = line_match.group(2)

    return zone_map, continent_names

def generate_lua_output(vendors, zone_map, continent_names):
    """Generate the new Lua file content."""
    lines = []

    # Header
    lines.append('--[[')
    lines.append('    Homestead - VendorDatabase')
    lines.append('    Database of housing decor vendors with locations and items')
    lines.append('')
    lines.append('    STRUCTURE: NPC-keyed for O(1) lookups')
    lines.append('    VendorDatabase.Vendors[npcID] = { name, mapID, x, y, zone, ... }')
    lines.append('')
    lines.append('    Generated by convert_vendor_db.py')
    lines.append(']]')
    lines.append('')
    lines.append('local addonName, HA = ...')
    lines.append('')
    lines.append('-- Create VendorDatabase module')
    lines.append('local VendorDatabase = {}')
    lines.append('HA.VendorDatabase = VendorDatabase')
    lines.append('')
    lines.append('-------------------------------------------------------------------------------')
    lines.append('-- Vendors (keyed by NPC ID)')
    lines.append('-------------------------------------------------------------------------------')
    lines.append('')
    lines.append('VendorDatabase.Vendors = {')

    # Sort vendors by expansion, then by npcID for readability
    expansion_order = ['TWW', 'DF', 'SL', 'BFA', 'Legion', 'WoD', 'MoP', 'WotLK', 'Classic', 'Events']

    def sort_key(v):
        exp_idx = expansion_order.index(v['expansion']) if v['expansion'] in expansion_order else 99
        return (exp_idx, v['npcID'])

    sorted_vendors = sorted(vendors, key=sort_key)

    current_expansion = None
    for vendor in sorted_vendors:
        # Add expansion comment header
        if vendor['expansion'] != current_expansion:
            current_expansion = vendor['expansion']
            lines.append(f'    -- {current_expansion}')

        lines.append(format_vendor_entry(vendor))

    lines.append('}')
    lines.append('')

    # Zone to Continent Map
    lines.append('-------------------------------------------------------------------------------')
    lines.append('-- Zone to Continent Mapping (for map pins)')
    lines.append('-------------------------------------------------------------------------------')
    lines.append('')
    lines.append('VendorDatabase.ZoneToContinentMap = {')
    for zone_id in sorted(zone_map.keys()):
        lines.append(f'    [{zone_id}] = {zone_map[zone_id]},')
    lines.append('}')
    lines.append('')

    # Continent Names
    lines.append('-------------------------------------------------------------------------------')
    lines.append('-- Continent Names')
    lines.append('-------------------------------------------------------------------------------')
    lines.append('')
    lines.append('VendorDatabase.ContinentNames = {')
    for cont_id in sorted(continent_names.keys()):
        lines.append(f'    [{cont_id}] = "{continent_names[cont_id]}",')
    lines.append('}')
    lines.append('')

    # Runtime index building function
    lines.append('-------------------------------------------------------------------------------')
    lines.append('-- Runtime Index Building')
    lines.append('-------------------------------------------------------------------------------')
    lines.append('')
    lines.append('-- Called once on ADDON_LOADED to build lookup indexes')
    lines.append('function VendorDatabase:BuildIndexes()')
    lines.append('    self.ByMapID = {}')
    lines.append('    self.ByExpansion = {}')
    lines.append('    self.ByName = {}')
    lines.append('')
    lines.append('    for npcID, vendor in pairs(self.Vendors) do')
    lines.append('        -- Index by mapID')
    lines.append('        local mapID = vendor.mapID')
    lines.append('        if mapID then')
    lines.append('            if not self.ByMapID[mapID] then')
    lines.append('                self.ByMapID[mapID] = {}')
    lines.append('            end')
    lines.append('            table.insert(self.ByMapID[mapID], npcID)')
    lines.append('        end')
    lines.append('')
    lines.append('        -- Index by expansion')
    lines.append('        local exp = vendor.expansion')
    lines.append('        if exp then')
    lines.append('            if not self.ByExpansion[exp] then')
    lines.append('                self.ByExpansion[exp] = {}')
    lines.append('            end')
    lines.append('            table.insert(self.ByExpansion[exp], npcID)')
    lines.append('        end')
    lines.append('')
    lines.append('        -- Index by name (lowercase for matching)')
    lines.append('        if vendor.name then')
    lines.append('            self.ByName[vendor.name:lower()] = npcID')
    lines.append('        end')
    lines.append('    end')
    lines.append('end')
    lines.append('')

    # Query functions
    lines.append('-------------------------------------------------------------------------------')
    lines.append('-- Query Functions')
    lines.append('-------------------------------------------------------------------------------')
    lines.append('')
    lines.append('-- Direct lookup by NPC ID: O(1)')
    lines.append('function VendorDatabase:GetVendor(npcID)')
    lines.append('    local vendor = self.Vendors[npcID]')
    lines.append('    if vendor then')
    lines.append('        vendor.npcID = npcID')
    lines.append('    end')
    lines.append('    return vendor')
    lines.append('end')
    lines.append('')
    lines.append('-- Check if vendor exists')
    lines.append('function VendorDatabase:HasVendor(npcID)')
    lines.append('    return self.Vendors[npcID] ~= nil')
    lines.append('end')
    lines.append('')
    lines.append('-- Get all vendors')
    lines.append('function VendorDatabase:GetAllVendors()')
    lines.append('    local all = {}')
    lines.append('    for npcID, vendor in pairs(self.Vendors) do')
    lines.append('        vendor.npcID = npcID')
    lines.append('        table.insert(all, vendor)')
    lines.append('    end')
    lines.append('    return all')
    lines.append('end')
    lines.append('')
    lines.append('-- Get vendors by map ID')
    lines.append('function VendorDatabase:GetVendorsByMapID(mapID)')
    lines.append('    local vendors = {}')
    lines.append('    local npcIDs = self.ByMapID and self.ByMapID[mapID]')
    lines.append('    if npcIDs then')
    lines.append('        for _, npcID in ipairs(npcIDs) do')
    lines.append('            local vendor = self.Vendors[npcID]')
    lines.append('            if vendor then')
    lines.append('                vendor.npcID = npcID')
    lines.append('                table.insert(vendors, vendor)')
    lines.append('            end')
    lines.append('        end')
    lines.append('    end')
    lines.append('    return vendors')
    lines.append('end')
    lines.append('')
    lines.append('-- Get vendors by expansion')
    lines.append('function VendorDatabase:GetVendorsByExpansion(expansion)')
    lines.append('    local vendors = {}')
    lines.append('    local npcIDs = self.ByExpansion and self.ByExpansion[expansion]')
    lines.append('    if npcIDs then')
    lines.append('        for _, npcID in ipairs(npcIDs) do')
    lines.append('            local vendor = self.Vendors[npcID]')
    lines.append('            if vendor then')
    lines.append('                vendor.npcID = npcID')
    lines.append('                table.insert(vendors, vendor)')
    lines.append('            end')
    lines.append('        end')
    lines.append('    end')
    lines.append('    return vendors')
    lines.append('end')
    lines.append('')
    lines.append('-- Find vendor by name (case-insensitive)')
    lines.append('function VendorDatabase:FindVendorByName(name)')
    lines.append('    if not name then return nil end')
    lines.append('    local npcID = self.ByName and self.ByName[name:lower()]')
    lines.append('    if npcID then')
    lines.append('        local vendor = self.Vendors[npcID]')
    lines.append('        if vendor then')
    lines.append('            vendor.npcID = npcID')
    lines.append('            return vendor')
    lines.append('        end')
    lines.append('    end')
    lines.append('    return nil')
    lines.append('end')
    lines.append('')
    lines.append('-- Get total vendor count')
    lines.append('function VendorDatabase:GetVendorCount()')
    lines.append('    local count = 0')
    lines.append('    for _ in pairs(self.Vendors) do')
    lines.append('        count = count + 1')
    lines.append('    end')
    lines.append('    return count')
    lines.append('end')

    return '\n'.join(lines)

def format_vendor_entry(vendor):
    """Format a single vendor as a Lua table entry."""
    npc_id = vendor['npcID']
    parts = [f'    [{npc_id}] = {{']

    # Required fields
    if 'name' in vendor:
        parts.append(f'        name = "{vendor["name"]}",')
    if 'mapID' in vendor:
        parts.append(f'        mapID = {vendor["mapID"]},')
    if 'x' in vendor and 'y' in vendor:
        parts.append(f'        x = {vendor["x"]}, y = {vendor["y"]},')
    if 'zone' in vendor:
        parts.append(f'        zone = "{vendor["zone"]}",')
    if 'subzone' in vendor:
        parts.append(f'        subzone = "{vendor["subzone"]}",')
    if 'faction' in vendor:
        parts.append(f'        faction = "{vendor["faction"]}",')
    if 'currency' in vendor:
        parts.append(f'        currency = "{vendor["currency"]}",')
    parts.append(f'        expansion = "{vendor["expansion"]}",')

    # Items
    if vendor.get('items'):
        item_str = ', '.join(str(i) for i in vendor['items'])
        parts.append(f'        items = {{ {item_str} }},')
    else:
        parts.append('        items = {},')

    # Optional fields
    if 'notes' in vendor:
        # Escape quotes in notes
        notes = vendor['notes'].replace('"', '\\"')
        parts.append(f'        notes = "{notes}",')
    if 'seasonal' in vendor:
        parts.append(f'        seasonal = "{vendor["seasonal"]}",')
    if 'covenant' in vendor:
        parts.append(f'        covenant = "{vendor["covenant"]}",')
    if 'class' in vendor:
        parts.append(f'        class = "{vendor["class"]}",')

    parts.append('    },')
    return '\n'.join(parts)

def main():
    # Paths
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    input_file = project_dir / 'Data' / 'VendorDatabase.lua'
    output_file = project_dir / 'Data' / 'VendorDatabase_new.lua'
    backup_file = project_dir / 'Data' / 'VendorDatabase_backup.lua'

    print(f"Reading: {input_file}")

    if not input_file.exists():
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)

    # Read input
    content = parse_lua_file(input_file)

    # Parse vendors
    print("Parsing vendor entries...")
    vendors, duplicates = extract_vendor_blocks(content)

    print(f"Found {len(vendors)} unique vendors")

    if duplicates:
        print(f"\nWARNING: Found {len(duplicates)} duplicate NPC IDs:")
        for dup in duplicates:
            print(f"  NPC {dup['npcID']} ({dup['name']}): in {dup['first_array']} and {dup['second_array']}")

    # Extract auxiliary tables
    zone_map, continent_names = extract_zone_maps(content)
    print(f"Found {len(zone_map)} zone mappings, {len(continent_names)} continent names")

    # Count by expansion
    exp_counts = defaultdict(int)
    for v in vendors:
        exp_counts[v['expansion']] += 1
    print("\nVendors by expansion:")
    for exp in ['TWW', 'DF', 'SL', 'BFA', 'Legion', 'WoD', 'MoP', 'WotLK', 'Classic', 'Events']:
        if exp in exp_counts:
            print(f"  {exp}: {exp_counts[exp]}")

    # Generate output
    print("\nGenerating new structure...")
    output = generate_lua_output(vendors, zone_map, continent_names)

    # Backup original
    print(f"Creating backup: {backup_file}")
    with open(backup_file, 'w', encoding='utf-8') as f:
        f.write(content)

    # Write output
    print(f"Writing: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(output)

    print("\nDone! Review the output file, then rename:")
    print(f"  1. Delete or archive: {input_file.name}")
    print(f"  2. Rename: {output_file.name} -> {input_file.name}")

if __name__ == '__main__':
    main()

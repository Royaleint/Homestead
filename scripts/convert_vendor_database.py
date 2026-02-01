#!/usr/bin/env python3
"""
Convert VendorDatabase.lua from array-based to NPC-keyed structure.

This script reads the current VendorDatabase.lua and outputs a new version
with vendors keyed by NPC ID for O(1) lookups.
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple

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
    "Cataclysm": "Cata",
    "Classic": "Classic",
    "OrderHalls": "Legion",
    "Neighborhoods": "TWW",
    "Events": "Events",
}

def parse_zone_string(zone: str) -> Tuple[str, Optional[str]]:
    """Split zone string into zone and subzone."""
    if " - " in zone:
        parts = zone.split(" - ", 1)
        return parts[0].strip(), parts[1].strip()
    return zone.strip(), None

def extract_item_ids(items_str: str) -> List[int]:
    """Extract item IDs from items table string."""
    item_ids = []
    # Match { itemID = 12345, ... } patterns
    pattern = r'\{\s*itemID\s*=\s*(\d+)'
    for match in re.finditer(pattern, items_str):
        item_ids.append(int(match.group(1)))
    return item_ids

def parse_vendor_entry(entry_str: str) -> Optional[Dict[str, Any]]:
    """Parse a single vendor entry from Lua table format."""
    vendor = {}

    # Extract npcID (required)
    npc_match = re.search(r'npcID\s*=\s*(\d+)', entry_str)
    if not npc_match:
        return None
    vendor['npcID'] = int(npc_match.group(1))

    # Extract name (required)
    name_match = re.search(r'name\s*=\s*"([^"]*)"', entry_str)
    if not name_match:
        return None
    vendor['name'] = name_match.group(1)

    # Extract mapID (required)
    map_match = re.search(r'mapID\s*=\s*(\d+)', entry_str)
    if not map_match:
        return None
    vendor['mapID'] = int(map_match.group(1))

    # Extract coords
    coords_match = re.search(r'coords\s*=\s*\{\s*x\s*=\s*([\d.]+)\s*,\s*y\s*=\s*([\d.]+)\s*\}', entry_str)
    if coords_match:
        vendor['x'] = float(coords_match.group(1))
        vendor['y'] = float(coords_match.group(2))

    # Extract zone and split into zone/subzone
    zone_match = re.search(r'zone\s*=\s*"([^"]*)"', entry_str)
    if zone_match:
        zone, subzone = parse_zone_string(zone_match.group(1))
        vendor['zone'] = zone
        if subzone:
            vendor['subzone'] = subzone

    # Extract faction
    faction_match = re.search(r'faction\s*=\s*"([^"]*)"', entry_str)
    if faction_match:
        vendor['faction'] = faction_match.group(1)

    # Extract currency
    currency_match = re.search(r'currency\s*=\s*"([^"]*)"', entry_str)
    if currency_match:
        vendor['currency'] = currency_match.group(1)

    # Extract optional fields
    notes_match = re.search(r'notes\s*=\s*"([^"]*)"', entry_str)
    if notes_match:
        vendor['notes'] = notes_match.group(1)

    seasonal_match = re.search(r'seasonal\s*=\s*"([^"]*)"', entry_str)
    if seasonal_match:
        vendor['seasonal'] = seasonal_match.group(1)

    covenant_match = re.search(r'covenant\s*=\s*"([^"]*)"', entry_str)
    if covenant_match:
        vendor['covenant'] = covenant_match.group(1)

    class_match = re.search(r'class\s*=\s*"([^"]*)"', entry_str)
    if class_match:
        vendor['class'] = class_match.group(1)

    # Extract items - find the items table
    items_match = re.search(r'items\s*=\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}', entry_str, re.DOTALL)
    if items_match:
        items_str = items_match.group(1)
        item_ids = extract_item_ids(items_str)
        vendor['items'] = item_ids
    else:
        vendor['items'] = []

    return vendor

def parse_vendor_array(content: str, array_name: str) -> List[Dict[str, Any]]:
    """Parse a vendor array from the Lua file."""
    vendors = []

    # Find the array
    pattern = rf'VendorDatabase\.{array_name}\s*=\s*\{{'
    match = re.search(pattern, content)
    if not match:
        return vendors

    start_pos = match.end()

    # Find matching closing brace
    brace_count = 1
    pos = start_pos
    while pos < len(content) and brace_count > 0:
        if content[pos] == '{':
            brace_count += 1
        elif content[pos] == '}':
            brace_count -= 1
        pos += 1

    array_content = content[start_pos:pos-1]

    # Find individual vendor entries (top-level { } blocks)
    entry_pattern = r'\{\s*npcID\s*='
    entries = []

    for match in re.finditer(entry_pattern, array_content):
        entry_start = match.start()
        # Find matching closing brace
        brace_count = 1
        pos = match.end()
        while pos < len(array_content) and brace_count > 0:
            if array_content[pos] == '{':
                brace_count += 1
            elif array_content[pos] == '}':
                brace_count -= 1
            pos += 1

        entry_str = array_content[entry_start:pos]
        vendor = parse_vendor_entry(entry_str)
        if vendor:
            vendors.append(vendor)

    return vendors

def format_lua_value(value: Any, indent: int = 0) -> str:
    """Format a Python value as Lua."""
    indent_str = "    " * indent

    if isinstance(value, str):
        # Escape quotes and backslashes
        escaped = value.replace('\\', '\\\\').replace('"', '\\"')
        return f'"{escaped}"'
    elif isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, (int, float)):
        if isinstance(value, float):
            # Format floats nicely
            return f"{value:.3f}".rstrip('0').rstrip('.')
        return str(value)
    elif isinstance(value, list):
        if not value:
            return "{}"
        if all(isinstance(x, int) for x in value):
            # Simple list of integers
            return "{ " + ", ".join(str(x) for x in value) + " }"
        # Complex list
        items = [format_lua_value(x, indent + 1) for x in value]
        return "{\n" + ",\n".join(f"{indent_str}    {item}" for item in items) + f"\n{indent_str}}}"
    elif isinstance(value, dict):
        items = []
        for k, v in value.items():
            formatted_v = format_lua_value(v, indent + 1)
            if isinstance(k, int):
                items.append(f"[{k}] = {formatted_v}")
            else:
                items.append(f"{k} = {formatted_v}")
        return "{\n" + ",\n".join(f"{indent_str}    {item}" for item in items) + f"\n{indent_str}}}"
    else:
        return str(value)

def generate_vendor_entry(npc_id: int, vendor: Dict[str, Any]) -> str:
    """Generate a single vendor entry for the new format."""
    lines = []
    lines.append(f"    [{npc_id}] = {{")

    # Required fields in specific order
    lines.append(f'        name = "{vendor["name"]}",')
    lines.append(f'        mapID = {vendor["mapID"]},')

    if 'x' in vendor and 'y' in vendor:
        lines.append(f'        x = {vendor["x"]:.3f},')
        lines.append(f'        y = {vendor["y"]:.3f},')

    if 'zone' in vendor:
        lines.append(f'        zone = "{vendor["zone"]}",')

    if 'subzone' in vendor:
        lines.append(f'        subzone = "{vendor["subzone"]}",')

    if 'faction' in vendor:
        lines.append(f'        faction = "{vendor["faction"]}",')

    if 'currency' in vendor:
        lines.append(f'        currency = "{vendor["currency"]}",')

    if 'expansion' in vendor:
        lines.append(f'        expansion = "{vendor["expansion"]}",')

    # Items
    if vendor.get('items'):
        items_str = ", ".join(str(i) for i in vendor['items'])
        lines.append(f'        items = {{ {items_str} }},')
    else:
        lines.append('        items = {},')

    # Optional fields
    if 'notes' in vendor:
        escaped_notes = vendor['notes'].replace('"', '\\"')
        lines.append(f'        notes = "{escaped_notes}",')

    if 'seasonal' in vendor:
        lines.append(f'        seasonal = "{vendor["seasonal"]}",')

    if 'covenant' in vendor:
        lines.append(f'        covenant = "{vendor["covenant"]}",')

    if 'class' in vendor:
        lines.append(f'        class = "{vendor["class"]}",')

    lines.append("    },")
    return "\n".join(lines)

def main():
    # Read the input file
    input_path = Path(__file__).parent.parent / "Data" / "VendorDatabase.lua"

    if not input_path.exists():
        print(f"Error: Could not find {input_path}")
        sys.exit(1)

    print(f"Reading {input_path}...")
    content = input_path.read_text(encoding='utf-8')

    # Parse all vendor arrays
    all_vendors: Dict[int, Dict[str, Any]] = {}
    duplicates: List[Tuple[int, str, str]] = []

    arrays_to_parse = [
        "TWW", "Undermine", "Karesh", "Dragonflight", "Shadowlands",
        "BFA", "WoD", "MoP", "WotLK", "Cataclysm", "Classic",
        "OrderHalls", "Neighborhoods", "Events"
    ]

    for array_name in arrays_to_parse:
        print(f"Parsing {array_name}...")
        vendors = parse_vendor_array(content, array_name)
        expansion = EXPANSION_MAP.get(array_name, array_name)

        for vendor in vendors:
            npc_id = vendor['npcID']
            vendor['expansion'] = expansion

            if npc_id in all_vendors:
                existing = all_vendors[npc_id]
                duplicates.append((npc_id, existing['name'], vendor['name']))
                print(f"  WARNING: Duplicate NPC ID {npc_id}:")
                print(f"    Existing: {existing['name']} ({existing.get('zone', 'unknown')})")
                print(f"    New: {vendor['name']} ({vendor.get('zone', 'unknown')})")
                # Keep the one with more items or more complete data
                if len(vendor.get('items', [])) > len(existing.get('items', [])):
                    all_vendors[npc_id] = vendor
            else:
                all_vendors[npc_id] = vendor

        print(f"  Found {len(vendors)} vendors")

    print(f"\nTotal unique vendors: {len(all_vendors)}")
    if duplicates:
        print(f"Duplicates found: {len(duplicates)}")

    # Extract ZoneToContinentMap and ContinentNames
    zone_map_match = re.search(
        r'VendorDatabase\.ZoneToContinentMap\s*=\s*\{([^}]+(?:\[[^\]]+\][^}]+)*)\}',
        content, re.DOTALL
    )
    zone_map_content = zone_map_match.group(0) if zone_map_match else ""

    continent_names_match = re.search(
        r'VendorDatabase\.ContinentNames\s*=\s*\{([^}]+)\}',
        content, re.DOTALL
    )
    continent_names_content = continent_names_match.group(0) if continent_names_match else ""

    # Generate the new file
    output_lines = []

    # Header
    output_lines.append('''--[[
    Homestead - VendorDatabase
    Database of housing decor vendors with locations and items

    This file contains the actual vendor data for housing decor vendors.
    Data is loaded by VendorData.lua on initialization.

    STRUCTURE: Vendors are keyed by NPC ID for O(1) lookups.

    Data sources:
    - Wowhead Housing Guides (https://www.wowhead.com/guide/player-housing/)
    - In-game research

    Map IDs Reference:
    - Dornogal: 2339
    - Isle of Dorn: 2248
    - The Ringing Deeps: 2214
    - Hallowfall: 2215
    - Undermine: 2346
    - Tazavesh (K'aresh): 2472
    - Stormwind City: 84
    - Orgrimmar: 85
    - Ironforge: 87
    - Darnassus: 89
    - Boralus: 1161
    - Dazar'alor: 1165
    - Valdrakken: 2112
    - Amirdrassil/Bel'ameth: 2239
]]

local addonName, HA = ...

-- Create VendorDatabase module
local VendorDatabase = {}
HA.VendorDatabase = VendorDatabase

-------------------------------------------------------------------------------
-- Vendor Database (keyed by NPC ID)
-------------------------------------------------------------------------------

VendorDatabase.Vendors = {
''')

    # Sort vendors by expansion then by name for readability
    sorted_vendors = sorted(
        all_vendors.items(),
        key=lambda x: (x[1].get('expansion', 'ZZZ'), x[1].get('name', ''))
    )

    current_expansion = None
    for npc_id, vendor in sorted_vendors:
        exp = vendor.get('expansion', 'Unknown')
        if exp != current_expansion:
            if current_expansion is not None:
                output_lines.append("")
            output_lines.append(f"    -- {exp}")
            current_expansion = exp

        output_lines.append(generate_vendor_entry(npc_id, vendor))

    output_lines.append("}")
    output_lines.append("")

    # Add runtime indexes section
    output_lines.append('''-------------------------------------------------------------------------------
-- Runtime Indexes (built on load, not stored)
-------------------------------------------------------------------------------

-- These are populated by BuildIndexes()
VendorDatabase.ByMapID = {}       -- [mapID] = { npcID1, npcID2, ... }
VendorDatabase.ByExpansion = {}   -- [expansion] = { npcID1, npcID2, ... }
VendorDatabase.ByName = {}        -- [lowercase name] = npcID

-------------------------------------------------------------------------------
-- Zone to Continent Mapping (for map pins)
-------------------------------------------------------------------------------

''')

    # Add the zone map (preserve original)
    output_lines.append(zone_map_content)
    output_lines.append("")
    output_lines.append("-- Continent names for display")
    output_lines.append(continent_names_content)
    output_lines.append("")

    # Add new functions
    output_lines.append('''-------------------------------------------------------------------------------
-- Index Building
-------------------------------------------------------------------------------

function VendorDatabase:BuildIndexes()
    -- Clear existing indexes
    self.ByMapID = {}
    self.ByExpansion = {}
    self.ByName = {}

    for npcID, vendor in pairs(self.Vendors) do
        -- Index by mapID
        local mapID = vendor.mapID
        if mapID then
            if not self.ByMapID[mapID] then
                self.ByMapID[mapID] = {}
            end
            table.insert(self.ByMapID[mapID], npcID)
        end

        -- Index by expansion
        local exp = vendor.expansion
        if exp then
            if not self.ByExpansion[exp] then
                self.ByExpansion[exp] = {}
            end
            table.insert(self.ByExpansion[exp], npcID)
        end

        -- Index by name (lowercase for matching)
        if vendor.name then
            self.ByName[vendor.name:lower()] = npcID
        end
    end
end

-------------------------------------------------------------------------------
-- Query Functions
-------------------------------------------------------------------------------

-- Direct lookup by NPC ID: O(1)
function VendorDatabase:GetVendor(npcID)
    local vendor = self.Vendors[npcID]
    if vendor then
        -- Return a copy with npcID included
        local result = {}
        for k, v in pairs(vendor) do
            result[k] = v
        end
        result.npcID = npcID
        -- Convert x,y back to coords for compatibility
        if vendor.x and vendor.y then
            result.coords = { x = vendor.x, y = vendor.y }
        end
        return result
    end
    return nil
end

-- Check if vendor exists
function VendorDatabase:HasVendor(npcID)
    return self.Vendors[npcID] ~= nil
end

-- Get all vendors
function VendorDatabase:GetAllVendors()
    local all = {}
    for npcID, vendor in pairs(self.Vendors) do
        local v = self:GetVendor(npcID)
        if v then
            table.insert(all, v)
        end
    end
    return all
end

-- Get vendors by zone: O(1) index lookup + O(k) where k = vendors in zone
function VendorDatabase:GetVendorsByZone(zoneMapID)
    local vendors = {}
    local npcIDs = self.ByMapID[zoneMapID]
    if npcIDs then
        for _, npcID in ipairs(npcIDs) do
            local vendor = self:GetVendor(npcID)
            if vendor then
                table.insert(vendors, vendor)
            end
        end
    end
    return vendors
end

-- Get vendors by expansion
function VendorDatabase:GetVendorsByExpansion(expansion)
    local vendors = {}
    local npcIDs = self.ByExpansion[expansion]
    if npcIDs then
        for _, npcID in ipairs(npcIDs) do
            local vendor = self:GetVendor(npcID)
            if vendor then
                table.insert(vendors, vendor)
            end
        end
    end
    return vendors
end

-- Find vendor by name (case-insensitive)
function VendorDatabase:FindVendorByName(name)
    if not name then return nil end
    local npcID = self.ByName[name:lower()]
    if npcID then
        return self:GetVendor(npcID)
    end
    return nil
end

-- Get vendors by continent
function VendorDatabase:GetVendorsByContinent(continentMapID)
    local vendors = {}
    for npcID, vendor in pairs(self.Vendors) do
        local vendorContinent = self.ZoneToContinentMap[vendor.mapID]
        if vendorContinent == continentMapID then
            local v = self:GetVendor(npcID)
            if v then
                table.insert(vendors, v)
            end
        end
    end
    return vendors
end

-- Get vendors by faction
function VendorDatabase:GetVendorsByFaction(faction)
    local vendors = {}
    local playerFaction = UnitFactionGroup("player")
    for npcID, vendor in pairs(self.Vendors) do
        if vendor.faction == "Neutral" or vendor.faction == faction or vendor.faction == playerFaction then
            local v = self:GetVendor(npcID)
            if v then
                table.insert(vendors, v)
            end
        end
    end
    return vendors
end

-- Get continent for a zone
function VendorDatabase:GetContinentForZone(zoneMapID)
    return self.ZoneToContinentMap[zoneMapID]
end

-- Get continent name
function VendorDatabase:GetContinentName(continentMapID)
    return self.ContinentNames[continentMapID]
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

-- Build indexes on load
VendorDatabase:BuildIndexes()
''')

    # Write output
    output_path = Path(__file__).parent.parent / "Data" / "VendorDatabase_new.lua"
    output_content = "\n".join(output_lines)
    output_path.write_text(output_content, encoding='utf-8')

    print(f"\nWrote {output_path}")
    print(f"Total lines: {len(output_lines)}")

    # Print summary
    print("\n=== Conversion Summary ===")
    print(f"Total vendors: {len(all_vendors)}")
    print(f"Duplicates resolved: {len(duplicates)}")

    # Count by expansion
    exp_counts = {}
    for vendor in all_vendors.values():
        exp = vendor.get('expansion', 'Unknown')
        exp_counts[exp] = exp_counts.get(exp, 0) + 1

    print("\nVendors by expansion:")
    for exp, count in sorted(exp_counts.items()):
        print(f"  {exp}: {count}")

if __name__ == "__main__":
    main()

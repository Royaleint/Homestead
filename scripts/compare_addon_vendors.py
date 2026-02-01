#!/usr/bin/env python3
"""
Addon Vendor Database Comparison Tool

Compares VendorDatabase.lua against HomeBound and DecorVendor addons
to find missing vendors and data discrepancies.
"""

import re
import json
from pathlib import Path
from collections import defaultdict

# Paths
PROJECT_DIR = Path(__file__).parent.parent
OUR_DB_PATH = PROJECT_DIR / 'Data' / 'VendorDatabase.lua'
HOMEBOUND_PATH = Path(r'C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HomeBound\db.lua')
DECORVENDOR_PATH = Path(r'C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\DecorVendor\dv.lua')

class VendorComparator:
    def __init__(self):
        self.our_vendors = {}
        self.homebound_vendors = {}
        self.decorvendor_vendors = {}
        self.findings = defaultdict(list)

    def parse_our_database(self):
        """Parse our VendorDatabase.lua"""
        print(f"Reading {OUR_DB_PATH}...")

        with open(OUR_DB_PATH, 'r', encoding='utf-8') as f:
            content = f.read()

        # Parse VendorDatabase.Vendors table
        vendors_match = re.search(r'VendorDatabase\.Vendors\s*=\s*\{(.+?)^\}',
                                  content, re.DOTALL | re.MULTILINE)
        if not vendors_match:
            print("ERROR: Could not find VendorDatabase.Vendors table")
            return False

        vendors_content = vendors_match.group(1)
        vendor_pattern = r'\[(\d+)\]\s*=\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)  \}'

        for match in re.finditer(vendor_pattern, vendors_content):
            npc_id = int(match.group(1))
            vendor_data = match.group(2)

            vendor = {'npcID': npc_id}

            # Extract fields
            name_match = re.search(r'name\s*=\s*"([^"]*)"', vendor_data)
            if name_match:
                vendor['name'] = name_match.group(1)

            x_match = re.search(r'x\s*=\s*([0-9.]+)', vendor_data)
            if x_match:
                vendor['x'] = float(x_match.group(1))

            y_match = re.search(r'y\s*=\s*([0-9.]+)', vendor_data)
            if y_match:
                vendor['y'] = float(y_match.group(1))

            mapid_match = re.search(r'mapID\s*=\s*(\d+)', vendor_data)
            if mapid_match:
                vendor['mapID'] = int(mapid_match.group(1))

            zone_match = re.search(r'zone\s*=\s*"([^"]*)"', vendor_data)
            if zone_match:
                vendor['zone'] = zone_match.group(1)

            expansion_match = re.search(r'expansion\s*=\s*"([^"]*)"', vendor_data)
            if expansion_match:
                vendor['expansion'] = expansion_match.group(1)

            self.our_vendors[npc_id] = vendor

        print(f"  Parsed {len(self.our_vendors)} vendors")
        return True

    def parse_homebound(self):
        """Parse HomeBound db.lua"""
        if not HOMEBOUND_PATH.exists():
            print(f"HomeBound not found at {HOMEBOUND_PATH}")
            return False

        print(f"\nReading {HOMEBOUND_PATH}...")

        with open(HOMEBOUND_PATH, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find db.vendors table (starts around line 2177)
        vendors_match = re.search(r'db\.vendors\s*=\s*\{(.+?)^\}',
                                  content, re.DOTALL | re.MULTILINE)
        if not vendors_match:
            print("  Could not find db.vendors table")
            return False

        vendors_content = vendors_match.group(1)

        # Pattern: { id = 12345, model3D = ..., title = "Name", x = ..., y = ..., mapID = ... }
        vendor_pattern = r'\{\s*id\s*=\s*(\d+)[^}]*title\s*=\s*"([^"]+)"[^}]*x\s*=\s*([0-9.]+)[^}]*y\s*=\s*([0-9.]+)[^}]*mapID\s*=\s*(\d+)'

        for match in re.finditer(vendor_pattern, vendors_content):
            npc_id = int(match.group(1))
            name = match.group(2)
            x = float(match.group(3))
            y = float(match.group(4))
            mapID = int(match.group(5))

            self.homebound_vendors[npc_id] = {
                'npcID': npc_id,
                'name': name,
                'x': x,
                'y': y,
                'mapID': mapID,
            }

        print(f"  Parsed {len(self.homebound_vendors)} vendors")
        return True

    def parse_decorvendor(self):
        """Parse DecorVendor dv.lua"""
        if not DECORVENDOR_PATH.exists():
            print(f"DecorVendor not found at {DECORVENDOR_PATH}")
            return False

        print(f"\nReading {DECORVENDOR_PATH}...")

        with open(DECORVENDOR_PATH, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find dv.npcs table
        npcs_match = re.search(r'dv\.npcs\s*=\s*\{(.+?)^\}',
                               content, re.DOTALL | re.MULTILINE)
        if not npcs_match:
            print("  Could not find dv.npcs table")
            return False

        npcs_content = npcs_match.group(1)

        # Pattern: { zone = "...", id = 12345, model3D = ..., title = "Name", x = ..., y = ..., mapID = ... }
        vendor_pattern = r'\{\s*zone\s*=\s*"([^"]*)"[^}]*id\s*=\s*(\d+)[^}]*title\s*=\s*"([^"]+)"[^}]*x\s*=\s*([0-9.]+)[^}]*y\s*=\s*([0-9.]+)[^}]*mapID\s*=\s*(\d+)'

        for match in re.finditer(vendor_pattern, npcs_content):
            zone = match.group(1)
            npc_id = int(match.group(2))
            name = match.group(3)
            x = float(match.group(4))
            y = float(match.group(5))
            mapID = int(match.group(6))

            self.decorvendor_vendors[npc_id] = {
                'npcID': npc_id,
                'name': name,
                'x': x,
                'y': y,
                'mapID': mapID,
                'zone': zone,
            }

        print(f"  Parsed {len(self.decorvendor_vendors)} vendors")
        return True

    def compare_vendors(self):
        """Cross-reference all vendor databases"""
        print("\n" + "=" * 70)
        print("COMPARING VENDOR DATABASES")
        print("=" * 70)

        # Collect all unique NPC IDs
        all_npc_ids = set()
        all_npc_ids.update(self.our_vendors.keys())
        all_npc_ids.update(self.homebound_vendors.keys())
        all_npc_ids.update(self.decorvendor_vendors.keys())

        print(f"\nTotal unique vendors across all sources: {len(all_npc_ids)}")
        print(f"  Our database:    {len(self.our_vendors)}")
        print(f"  HomeBound:       {len(self.homebound_vendors)}")
        print(f"  DecorVendor:     {len(self.decorvendor_vendors)}")

        # Find vendors missing from our database
        for npc_id in all_npc_ids:
            in_ours = npc_id in self.our_vendors
            in_hb = npc_id in self.homebound_vendors
            in_dv = npc_id in self.decorvendor_vendors

            # Vendors in other addons but not in ours
            if (in_hb or in_dv) and not in_ours:
                source = []
                if in_hb:
                    source.append("HomeBound")
                    vendor_data = self.homebound_vendors[npc_id]
                if in_dv:
                    source.append("DecorVendor")
                    if not in_hb:
                        vendor_data = self.decorvendor_vendors[npc_id]

                self.findings['missing_from_ours'].append({
                    'npcID': npc_id,
                    'name': vendor_data.get('name', 'Unknown'),
                    'source': ' + '.join(source),
                    'x': vendor_data.get('x'),
                    'y': vendor_data.get('y'),
                    'mapID': vendor_data.get('mapID'),
                })

            # Check for data discrepancies
            if in_ours and (in_hb or in_dv):
                our_vendor = self.our_vendors[npc_id]

                # Compare with HomeBound
                if in_hb:
                    hb_vendor = self.homebound_vendors[npc_id]

                    # Name mismatch
                    if our_vendor.get('name') != hb_vendor.get('name'):
                        self.findings['name_mismatch'].append({
                            'npcID': npc_id,
                            'our_name': our_vendor.get('name', 'N/A'),
                            'homebound_name': hb_vendor.get('name', 'N/A'),
                        })

                    # Coordinate differences (threshold: 0.5 difference)
                    our_x = our_vendor.get('x', 0)
                    our_y = our_vendor.get('y', 0)
                    hb_x = hb_vendor.get('x', 0)
                    hb_y = hb_vendor.get('y', 0)

                    if (abs(our_x - hb_x) > 0.5 or abs(our_y - hb_y) > 0.5):
                        self.findings['coord_diff'].append({
                            'npcID': npc_id,
                            'name': our_vendor.get('name'),
                            'our_coords': f"({our_x:.2f}, {our_y:.2f})",
                            'homebound_coords': f"({hb_x:.2f}, {hb_y:.2f})",
                        })

                    # Map ID mismatch
                    if our_vendor.get('mapID') != hb_vendor.get('mapID'):
                        self.findings['mapid_mismatch'].append({
                            'npcID': npc_id,
                            'name': our_vendor.get('name'),
                            'our_mapID': our_vendor.get('mapID'),
                            'homebound_mapID': hb_vendor.get('mapID'),
                        })

                # Compare with DecorVendor
                if in_dv:
                    dv_vendor = self.decorvendor_vendors[npc_id]

                    # Coordinate differences
                    our_x = our_vendor.get('x', 0)
                    our_y = our_vendor.get('y', 0)
                    dv_x = dv_vendor.get('x', 0)
                    dv_y = dv_vendor.get('y', 0)

                    # Only report if HomeBound didn't already catch it
                    if not in_hb and (abs(our_x - dv_x) > 0.5 or abs(our_y - dv_y) > 0.5):
                        self.findings['coord_diff_dv'].append({
                            'npcID': npc_id,
                            'name': our_vendor.get('name'),
                            'our_coords': f"({our_x:.2f}, {our_y:.2f})",
                            'decorvendor_coords': f"({dv_x:.2f}, {dv_y:.2f})",
                        })

    def generate_report(self):
        """Generate comparison report"""
        lines = []
        lines.append("=" * 70)
        lines.append("VENDOR DATABASE COMPARISON REPORT")
        lines.append("Homestead vs HomeBound vs DecorVendor")
        lines.append("=" * 70)
        lines.append("")

        # Summary
        lines.append("SUMMARY")
        lines.append("-" * 70)
        lines.append(f"Vendors in our database:     {len(self.our_vendors)}")
        lines.append(f"Vendors in HomeBound:        {len(self.homebound_vendors)}")
        lines.append(f"Vendors in DecorVendor:      {len(self.decorvendor_vendors)}")
        lines.append(f"Missing from our DB:         {len(self.findings['missing_from_ours'])}")
        lines.append(f"Name mismatches:             {len(self.findings['name_mismatch'])}")
        lines.append(f"Coordinate differences (HB): {len(self.findings['coord_diff'])}")
        lines.append(f"Coordinate differences (DV): {len(self.findings['coord_diff_dv'])}")
        lines.append(f"Map ID mismatches:           {len(self.findings['mapid_mismatch'])}")
        lines.append("")

        # Missing vendors
        if self.findings['missing_from_ours']:
            lines.append("VENDORS MISSING FROM OUR DATABASE")
            lines.append("-" * 70)
            lines.append("These vendors exist in other addons but not in ours:")
            lines.append("")
            for vendor in sorted(self.findings['missing_from_ours'],
                                 key=lambda x: x['npcID']):
                lines.append(f"[{vendor['npcID']}] {vendor['name']}")
                lines.append(f"  Source: {vendor['source']}")
                lines.append(f"  Coords: ({vendor['x']:.2f}, {vendor['y']:.2f}), MapID: {vendor['mapID']}")
                lines.append("")

        # Name mismatches
        if self.findings['name_mismatch']:
            lines.append("NAME MISMATCHES")
            lines.append("-" * 70)
            for issue in sorted(self.findings['name_mismatch'],
                                key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}]")
                lines.append(f"  Our DB:     \"{issue['our_name']}\"")
                lines.append(f"  HomeBound:  \"{issue['homebound_name']}\"")
                lines.append("")

        # Coordinate differences
        if self.findings['coord_diff']:
            lines.append("COORDINATE DIFFERENCES (HomeBound)")
            lines.append("-" * 70)
            for issue in sorted(self.findings['coord_diff'],
                                key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']}")
                lines.append(f"  Our DB:     {issue['our_coords']}")
                lines.append(f"  HomeBound:  {issue['homebound_coords']}")
                lines.append("")

        if self.findings['coord_diff_dv']:
            lines.append("COORDINATE DIFFERENCES (DecorVendor)")
            lines.append("-" * 70)
            for issue in sorted(self.findings['coord_diff_dv'],
                                key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']}")
                lines.append(f"  Our DB:       {issue['our_coords']}")
                lines.append(f"  DecorVendor:  {issue['decorvendor_coords']}")
                lines.append("")

        # Map ID mismatches
        if self.findings['mapid_mismatch']:
            lines.append("MAP ID MISMATCHES")
            lines.append("-" * 70)
            for issue in sorted(self.findings['mapid_mismatch'],
                                key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']}")
                lines.append(f"  Our DB:     {issue['our_mapID']}")
                lines.append(f"  HomeBound:  {issue['homebound_mapID']}")
                lines.append("")

        # All clear
        if not any(self.findings.values()):
            lines.append("✓ NO ISSUES FOUND - All vendors match perfectly!")
            lines.append("")

        return '\n'.join(lines)

def main():
    comparator = VendorComparator()

    # Parse all databases
    if not comparator.parse_our_database():
        return 1

    comparator.parse_homebound()
    comparator.parse_decorvendor()

    # Compare
    comparator.compare_vendors()

    # Generate report
    report = comparator.generate_report()

    # Save report
    report_file = PROJECT_DIR / 'addon_vendor_comparison.txt'
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)

    print(f"\nReport saved to: {report_file}")
    print()
    print(report)

if __name__ == '__main__':
    main()

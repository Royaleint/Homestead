#!/usr/bin/env python3
"""
Vendor Database Verification Tool

Verifies vendor data in VendorDatabase.lua against WoW.tools API.
"""

import re
import sys
import time
import json
import requests
from pathlib import Path
from collections import defaultdict

# Configuration
WOW_TOOLS_API = "https://wow.tools/dbc/api/peek/creature"
BUILD_VERSION = "11.1.0.60597"
RATE_LIMIT_DELAY = 1.0  # seconds between requests
CACHE_FILE = Path(__file__).parent / "npc_cache.json"

class VendorVerifier:
    def __init__(self, db_path):
        self.db_path = Path(db_path)
        self.vendors = []
        self.cache = self.load_cache()
        self.issues = defaultdict(list)
        self.stats = {
            'total': 0,
            'verified': 0,
            'api_calls': 0,
            'cache_hits': 0,
        }

    def load_cache(self):
        """Load cached NPC data from previous runs."""
        if CACHE_FILE.exists():
            try:
                with open(CACHE_FILE, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"Warning: Could not load cache: {e}")
        return {}

    def save_cache(self):
        """Save NPC data cache for future runs."""
        try:
            with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.cache, f, indent=2)
            print(f"Cache saved: {len(self.cache)} NPCs")
        except Exception as e:
            print(f"Warning: Could not save cache: {e}")

    def parse_lua_file(self):
        """Parse VendorDatabase.lua and extract vendor data."""
        print(f"Reading {self.db_path}...")

        with open(self.db_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find the Vendors table
        vendors_match = re.search(r'VendorDatabase\.Vendors\s*=\s*\{(.+?)^\}', content, re.DOTALL | re.MULTILINE)
        if not vendors_match:
            print("ERROR: Could not find VendorDatabase.Vendors table")
            return False

        vendors_content = vendors_match.group(1)

        # Parse individual vendor entries
        # Pattern: [npcID] = { ... },
        vendor_pattern = r'\[(\d+)\]\s*=\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}'

        for match in re.finditer(vendor_pattern, vendors_content):
            npc_id = int(match.group(1))
            vendor_data = match.group(2)

            vendor = {'npcID': npc_id}

            # Extract fields
            name_match = re.search(r'name\s*=\s*"([^"]*)"', vendor_data)
            if name_match:
                vendor['name'] = name_match.group(1)

            map_match = re.search(r'mapID\s*=\s*(\d+)', vendor_data)
            if map_match:
                vendor['mapID'] = int(map_match.group(1))

            x_match = re.search(r'x\s*=\s*([0-9.]+)', vendor_data)
            if x_match:
                vendor['x'] = float(x_match.group(1))

            y_match = re.search(r'y\s*=\s*([0-9.]+)', vendor_data)
            if y_match:
                vendor['y'] = float(y_match.group(1))

            zone_match = re.search(r'zone\s*=\s*"([^"]*)"', vendor_data)
            if zone_match:
                vendor['zone'] = zone_match.group(1)

            subzone_match = re.search(r'subzone\s*=\s*"([^"]*)"', vendor_data)
            if subzone_match:
                vendor['subzone'] = subzone_match.group(1)

            expansion_match = re.search(r'expansion\s*=\s*"([^"]*)"', vendor_data)
            if expansion_match:
                vendor['expansion'] = expansion_match.group(1)

            # Extract items array
            items_match = re.search(r'items\s*=\s*\{([^}]*)\}', vendor_data)
            if items_match:
                items_str = items_match.group(1)
                vendor['items'] = [int(x) for x in re.findall(r'\d+', items_str)]
            else:
                vendor['items'] = []

            self.vendors.append(vendor)

        print(f"Parsed {len(self.vendors)} vendors")
        return True

    def verify_npc_id(self, npc_id, vendor_name):
        """Verify NPC ID against WoW.tools API."""
        # Check cache first
        cache_key = str(npc_id)
        if cache_key in self.cache:
            self.stats['cache_hits'] += 1
            return self.cache[cache_key]

        # Make API request
        try:
            url = f"{WOW_TOOLS_API}?build={BUILD_VERSION}&col=ID&val={npc_id}"

            self.stats['api_calls'] += 1
            print(f"  API request {self.stats['api_calls']}: NPC {npc_id} ({vendor_name})...", end='', flush=True)

            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'application/json',
            }

            response = requests.get(url, headers=headers, timeout=10)

            if response.status_code == 200:
                data = response.json()

                # Cache the result
                self.cache[cache_key] = data

                print(" OK" if data else " NOT FOUND")

                # Rate limit
                time.sleep(RATE_LIMIT_DELAY)

                return data
            elif response.status_code == 403:
                print(f" BLOCKED (API access restricted)")
                # Return special marker to skip API validation
                return "API_BLOCKED"
            else:
                print(f" HTTP {response.status_code}")
                return None

        except Exception as e:
            print(f" ERROR: {e}")
            return None

    def verify_all_vendors(self):
        """Verify all vendors and collect issues."""
        print("\nVerifying vendor database...")
        print(f"Cache: {len(self.cache)} NPCs")
        print()

        self.stats['total'] = len(self.vendors)
        api_blocked = False

        for i, vendor in enumerate(self.vendors, 1):
            npc_id = vendor['npcID']
            name = vendor.get('name', 'Unknown')
            zone = vendor.get('zone', '')
            subzone = vendor.get('subzone', '')
            location = f"{zone} - {subzone}" if subzone else zone

            # Check for placeholder coordinates
            x = vendor.get('x', 0)
            y = vendor.get('y', 0)
            if (x == 0.5 and y == 0.5) or (x == 0.50 and y == 0.50):
                self.issues['placeholder_coords'].append({
                    'npcID': npc_id,
                    'name': name,
                    'location': location,
                })

            # Check for empty item lists
            if not vendor.get('items'):
                self.issues['empty_items'].append({
                    'npcID': npc_id,
                    'name': name,
                    'location': location,
                })

            # Check for missing required fields
            if not name:
                self.issues['missing_name'].append({
                    'npcID': npc_id,
                    'location': location,
                })

            if not vendor.get('mapID'):
                self.issues['missing_mapid'].append({
                    'npcID': npc_id,
                    'name': name,
                    'location': location,
                })

            # Verify NPC ID exists (only if API not blocked)
            if not api_blocked:
                npc_data = self.verify_npc_id(npc_id, name)

                if npc_data == "API_BLOCKED":
                    api_blocked = True
                    print("\nAPI access blocked - skipping external validation")
                    print("Continuing with local validation only...\n")
                elif npc_data is None or len(npc_data) == 0:
                    # NPC not found in game data
                    self.issues['not_found'].append({
                        'npcID': npc_id,
                        'name': name,
                        'location': location,
                    })
                else:
                    # NPC found - check name
                    self.stats['verified'] += 1

                    # Extract name from API response
                    # Response format: [{"ID": 12345, "Name_lang": "NPC Name", ...}]
                    if isinstance(npc_data, list) and len(npc_data) > 0:
                        api_name = npc_data[0].get('Name_lang', '')

                        # Compare names (case-insensitive)
                        if api_name and api_name.lower() != name.lower():
                            self.issues['name_mismatch'].append({
                                'npcID': npc_id,
                                'database_name': name,
                                'api_name': api_name,
                                'location': location,
                            })

        if api_blocked:
            self.stats['api_blocked'] = True

        print()

    def generate_report(self):
        """Generate verification report."""
        lines = []
        lines.append("=" * 70)
        lines.append("VENDOR DATABASE VERIFICATION")
        lines.append("=" * 70)
        lines.append("")

        # Summary
        lines.append("SUMMARY")
        lines.append("-" * 70)
        lines.append(f"Total vendors:     {self.stats['total']}")
        if self.stats.get('api_blocked'):
            lines.append(f"External verify:   SKIPPED (API access blocked)")
        else:
            lines.append(f"Verified valid:    {self.stats['verified']}")
        lines.append(f"Issues found:      {sum(len(issues) for issues in self.issues.values())}")
        lines.append(f"API calls made:    {self.stats['api_calls']}")
        lines.append(f"Cache hits:        {self.stats['cache_hits']}")
        lines.append("")

        if self.stats.get('api_blocked'):
            lines.append("NOTE: External API validation was blocked.")
            lines.append("Report shows only local database validation issues.")
            lines.append("")

        # NPC ID not found
        if self.issues['not_found']:
            lines.append("NPC ID NOT FOUND (does not exist in game data)")
            lines.append("-" * 70)
            for issue in sorted(self.issues['not_found'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']} - {issue['location']}")
            lines.append("")

        # Name mismatches
        if self.issues['name_mismatch']:
            lines.append("NAME MISMATCH (NPC exists but name differs)")
            lines.append("-" * 70)
            for issue in sorted(self.issues['name_mismatch'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] Database: \"{issue['database_name']}\" | Actual: \"{issue['api_name']}\"")
                lines.append(f"           Location: {issue['location']}")
            lines.append("")

        # Placeholder coordinates
        if self.issues['placeholder_coords']:
            lines.append("PLACEHOLDER COORDINATES (0.5, 0.5)")
            lines.append("-" * 70)
            for issue in sorted(self.issues['placeholder_coords'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']} - {issue['location']} (needs coordinates)")
            lines.append("")

        # Empty item lists
        if self.issues['empty_items']:
            lines.append("EMPTY ITEM LISTS")
            lines.append("-" * 70)
            for issue in sorted(self.issues['empty_items'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']} - has no items defined")
            lines.append("")

        # Missing names
        if self.issues.get('missing_name'):
            lines.append("MISSING VENDOR NAMES")
            lines.append("-" * 70)
            for issue in sorted(self.issues['missing_name'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] - {issue['location']}")
            lines.append("")

        # Missing map IDs
        if self.issues.get('missing_mapid'):
            lines.append("MISSING MAP IDS (won't show on map)")
            lines.append("-" * 70)
            for issue in sorted(self.issues['missing_mapid'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']} - {issue['location']}")
            lines.append("")

        # All clear
        if not any(self.issues.values()):
            lines.append("✓ NO ISSUES FOUND - All vendors verified successfully!")
            lines.append("")

        report = '\n'.join(lines)
        return report

def main():
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    db_file = project_dir / 'Data' / 'VendorDatabase.lua'

    if not db_file.exists():
        print(f"ERROR: VendorDatabase.lua not found at {db_file}")
        sys.exit(1)

    verifier = VendorVerifier(db_file)

    # Parse the database
    if not verifier.parse_lua_file():
        sys.exit(1)

    # Verify all vendors
    verifier.verify_all_vendors()

    # Generate report
    report = verifier.generate_report()

    # Save report
    report_file = project_dir / 'vendor_verification_report.txt'
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)

    print(f"Report saved to: {report_file}")
    print()
    print(report)

    # Save cache
    verifier.save_cache()

if __name__ == '__main__':
    main()

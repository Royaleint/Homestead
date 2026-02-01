#!/usr/bin/env python3
"""
Vendor Database Verification Tool - AllTheThings Edition

Verifies vendor data against AllTheThings addon database.
"""

import re
import sys
import json
import requests
from pathlib import Path
from collections import defaultdict

# AllTheThings GitHub repository - using Database repo which has cleaner structure
ATT_REPO = "ATTWoWAddon/Database"
ATT_BRANCH = "master"
ATT_RAW_URL = f"https://raw.githubusercontent.com/{ATT_REPO}/{ATT_BRANCH}"

# Cache directory
CACHE_DIR = Path(__file__).parent / "att_cache"

class ATTVerifier:
    def __init__(self, db_path):
        self.db_path = Path(db_path)
        self.vendors = []
        self.att_npcs = {}
        self.att_housing_vendors = {}
        self.issues = defaultdict(list)
        self.stats = {
            'total': 0,
            'verified': 0,
            'not_in_att': 0,
            'name_mismatch': 0,
        }

        # Ensure cache directory exists
        CACHE_DIR.mkdir(exist_ok=True)

    def fetch_att_file(self, file_path):
        """Fetch a file from AllTheThings GitHub repo."""
        cache_file = CACHE_DIR / file_path.replace('/', '_')

        # Check cache first
        if cache_file.exists():
            print(f"  Using cached: {file_path}")
            with open(cache_file, 'r', encoding='utf-8') as f:
                return f.read()

        # Fetch from GitHub
        url = f"{ATT_RAW_URL}/{file_path}"
        print(f"  Fetching: {file_path}")

        try:
            response = requests.get(url, timeout=30)
            if response.status_code == 200:
                content = response.text

                # Cache it
                with open(cache_file, 'w', encoding='utf-8') as f:
                    f.write(content)

                return content
            else:
                print(f"    HTTP {response.status_code}")
                return None
        except Exception as e:
            print(f"    ERROR: {e}")
            return None

    def find_att_data_files(self):
        """Find relevant AllTheThings vendor data files."""
        print("\nFinding AllTheThings vendor data files...")

        # AllTheThings Database has vendor data in zone-specific Vendors.lua files
        # We're primarily interested in Khaz Algar (TWW) zones for housing vendors
        vendor_file_paths = [
            "02 - Outdoor Zones/15 Khaz Algar/1 - Dornogal/Vendors.lua",
            "02 - Outdoor Zones/15 Khaz Algar/Isle of Dorn/Vendors.lua",
            "02 - Outdoor Zones/15 Khaz Algar/The Ringing Deeps/Vendors.lua",
            "02 - Outdoor Zones/15 Khaz Algar/Hallowfall/Vendors.lua",
            "02 - Outdoor Zones/15 Khaz Algar/Azj-Kahet/Vendors.lua",
            "02 - Outdoor Zones/15 Khaz Algar/Siren Isle/Vendors.lua",
        ]

        files_found = []
        for path in vendor_file_paths:
            content = self.fetch_att_file(path)
            if content:
                files_found.append((path, content))

        if not files_found:
            print("WARNING: Could not find ATT vendor data files")

        return files_found

    def parse_att_npc_data(self, content):
        """Parse AllTheThings vendor data."""
        print("  Parsing vendor data...")

        # ATT Database uses format:
        # n(123456, {	-- Vendor Name <Title>
        #     ["coord"] = { x, y, ZONE },
        #     ["g"] = { items... },
        # }),

        # Pattern to match: n(npcID, { -- Name <optional title>
        vendor_pattern = r'n\((\d+),\s*\{[^\n]*--\s*([^<\n]+?)(?:\s*<[^>]+>)?\s*(?:\n|$)'

        matches = re.finditer(vendor_pattern, content, re.MULTILINE)
        count = 0

        for match in matches:
            npc_id = int(match.group(1))
            name = match.group(2).strip()

            if name:
                self.att_npcs[npc_id] = {
                    'name': name,
                    'id': npc_id,
                }
                count += 1

        print(f"    Found {count} vendors")
        return count

    def search_att_repo_structure(self):
        """Search the ATT repository to find data files."""
        print("\nSearching AllTheThings repository structure...")

        # Try to fetch the main repo tree
        api_url = f"https://api.github.com/repos/{ATT_REPO}/git/trees/{ATT_BRANCH}?recursive=1"

        try:
            response = requests.get(api_url, timeout=30)
            if response.status_code == 200:
                tree = response.json()

                # Look for files that might contain NPC data
                npc_files = []
                for item in tree.get('tree', []):
                    path = item.get('path', '')
                    if any(keyword in path.lower() for keyword in ['npc', 'creature', 'vendor']) and path.endswith('.lua'):
                        npc_files.append(path)

                print(f"Found {len(npc_files)} potential data files:")
                for f in npc_files[:10]:  # Show first 10
                    print(f"  - {f}")

                return npc_files[:5]  # Try first 5
        except Exception as e:
            print(f"Error searching repo: {e}")

        return []

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
        vendor_pattern = r'\[(\d+)\]\s*=\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}'

        for match in re.finditer(vendor_pattern, vendors_content):
            npc_id = int(match.group(1))
            vendor_data = match.group(2)

            vendor = {'npcID': npc_id}

            # Extract fields
            name_match = re.search(r'name\s*=\s*"([^"]*)"', vendor_data)
            if name_match:
                vendor['name'] = name_match.group(1)

            zone_match = re.search(r'zone\s*=\s*"([^"]*)"', vendor_data)
            if zone_match:
                vendor['zone'] = zone_match.group(1)

            subzone_match = re.search(r'subzone\s*=\s*"([^"]*)"', vendor_data)
            if subzone_match:
                vendor['subzone'] = subzone_match.group(1)

            expansion_match = re.search(r'expansion\s*=\s*"([^"]*)"', vendor_data)
            if expansion_match:
                vendor['expansion'] = expansion_match.group(1)

            # Extract items
            items_match = re.search(r'items\s*=\s*\{([^}]*)\}', vendor_data)
            if items_match:
                items_str = items_match.group(1)
                vendor['items'] = [int(x) for x in re.findall(r'\d+', items_str)]
            else:
                vendor['items'] = []

            self.vendors.append(vendor)

        print(f"Parsed {len(self.vendors)} vendors")
        return True

    def verify_vendors(self):
        """Verify our vendors against ATT data."""
        print("\nVerifying vendors against AllTheThings data...")

        self.stats['total'] = len(self.vendors)

        if not self.att_npcs:
            print("WARNING: No ATT NPC data loaded - skipping verification")
            return

        for vendor in self.vendors:
            npc_id = vendor['npcID']
            name = vendor.get('name', 'Unknown')
            zone = vendor.get('zone', '')
            subzone = vendor.get('subzone', '')
            location = f"{zone} - {subzone}" if subzone else zone

            # Check if NPC exists in ATT
            if npc_id not in self.att_npcs:
                self.stats['not_in_att'] += 1
                self.issues['not_in_att'].append({
                    'npcID': npc_id,
                    'name': name,
                    'location': location,
                })
            else:
                self.stats['verified'] += 1
                att_name = self.att_npcs[npc_id]['name']

                # Check for name mismatch
                if att_name.lower() != name.lower():
                    self.stats['name_mismatch'] += 1
                    self.issues['name_mismatch'].append({
                        'npcID': npc_id,
                        'database_name': name,
                        'att_name': att_name,
                        'location': location,
                    })

            # Check placeholder coords and empty items (local validation)
            x = vendor.get('x', 0)
            y = vendor.get('y', 0)
            if (x == 0.5 and y == 0.5) or (x == 0.50 and y == 0.50):
                self.issues['placeholder_coords'].append({
                    'npcID': npc_id,
                    'name': name,
                    'location': location,
                })

            if not vendor.get('items'):
                self.issues['empty_items'].append({
                    'npcID': npc_id,
                    'name': name,
                    'location': location,
                })

    def generate_report(self):
        """Generate verification report."""
        lines = []
        lines.append("=" * 70)
        lines.append("VENDOR DATABASE VERIFICATION - AllTheThings Edition")
        lines.append("=" * 70)
        lines.append("")

        # Summary
        lines.append("SUMMARY")
        lines.append("-" * 70)
        lines.append(f"Total vendors:        {self.stats['total']}")
        lines.append(f"Verified in ATT:      {self.stats['verified']}")
        lines.append(f"Not found in ATT:     {self.stats['not_in_att']}")
        lines.append(f"Name mismatches:      {self.stats['name_mismatch']}")
        lines.append(f"Placeholder coords:   {len(self.issues['placeholder_coords'])}")
        lines.append(f"Empty item lists:     {len(self.issues['empty_items'])}")
        lines.append("")

        # Not in ATT
        if self.issues['not_in_att']:
            lines.append("NOT FOUND IN ALLTHETHINGS DATA")
            lines.append("-" * 70)
            lines.append("These NPCs don't exist in ATT database (may be incorrect IDs)")
            lines.append("")
            for issue in sorted(self.issues['not_in_att'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']} - {issue['location']}")
            lines.append("")

        # Name mismatches
        if self.issues['name_mismatch']:
            lines.append("NAME MISMATCHES")
            lines.append("-" * 70)
            lines.append("NPC exists but name differs from ATT database")
            lines.append("")
            for issue in sorted(self.issues['name_mismatch'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] Our DB: \"{issue['database_name']}\"")
                lines.append(f"           ATT DB: \"{issue['att_name']}\"")
                lines.append(f"         Location: {issue['location']}")
                lines.append("")

        # Placeholder coordinates
        if self.issues['placeholder_coords']:
            lines.append("PLACEHOLDER COORDINATES (0.5, 0.5)")
            lines.append("-" * 70)
            for issue in sorted(self.issues['placeholder_coords'], key=lambda x: x['npcID']):
                lines.append(f"[{issue['npcID']}] {issue['name']} - {issue['location']}")
            lines.append("")

        # Empty item lists
        if self.issues['empty_items']:
            lines.append("EMPTY ITEM LISTS (first 20)")
            lines.append("-" * 70)
            for issue in sorted(self.issues['empty_items'], key=lambda x: x['npcID'])[:20]:
                lines.append(f"[{issue['npcID']}] {issue['name']}")
            if len(self.issues['empty_items']) > 20:
                lines.append(f"... and {len(self.issues['empty_items']) - 20} more")
            lines.append("")

        # All clear
        if not any(self.issues.values()):
            lines.append("✓ NO ISSUES FOUND - All vendors verified successfully!")
            lines.append("")

        return '\n'.join(lines)

def main():
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    db_file = project_dir / 'Data' / 'VendorDatabase.lua'

    if not db_file.exists():
        print(f"ERROR: VendorDatabase.lua not found at {db_file}")
        sys.exit(1)

    verifier = ATTVerifier(db_file)

    # Parse our database
    if not verifier.parse_lua_file():
        sys.exit(1)

    # Try to find and load ATT data
    print("\nLoading AllTheThings data...")

    # First try known paths
    att_files = verifier.find_att_data_files()

    if not att_files:
        # Search repo structure
        potential_files = verifier.search_att_repo_structure()
        for file_path in potential_files:
            content = verifier.fetch_att_file(file_path)
            if content:
                att_files.append((file_path, content))

    # Parse all found files
    total_npcs = 0
    for file_path, content in att_files:
        print(f"\nProcessing {file_path}...")
        count = verifier.parse_att_npc_data(content)
        total_npcs += count

    print(f"\nTotal NPCs loaded from ATT: {total_npcs}")

    # Verify vendors
    verifier.verify_vendors()

    # Generate report
    report = verifier.generate_report()

    # Save report
    report_file = project_dir / 'vendor_verification_att_report.txt'
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)

    print(f"\nReport saved to: {report_file}")
    print()
    print(report)

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
WoW Housing API Documentation Parser

Parses Lua documentation files from Townlong Yak and generates a comprehensive
markdown reference document for the Homestead addon.
"""

import zipfile
import re
import os
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field

# File processing order by tier
TIER_1_FILES = [
    "HousingDecorSharedDocumentation.lua",
    "HousingCatalogUIDocumentation.lua",
    "HousingDecorUIDocumentation.lua",
    "HousingUISharedDocumentation.lua",
    "HousingUIDocumentation.lua",
    "PlayerHousingConstantsDocumentation.lua",
    "MerchantFrameDocumentation.lua",
]

TIER_2_FILES = [
    "HousingLayoutPinFrameAPIDocumentation.lua",
    "HousingFixturePointFrameAPIDocumentation.lua",
    "HouseEditorUIDocumentation.lua",
    "HousingLayoutUIDocumentation.lua",
    "HousingLayoutUITypesDocumentation.lua",
    "DyeColorInfoDocumentation.lua",
    "DyeColorInfoSharedDocumentation.lua",
]

TIER_3_FILES = [
    "HousingBasicModeUIDocumentation.lua",
    "HousingCleanupModeUIDocumentation.lua",
    "HousingCustomizeModeUIDocumentation.lua",
    "HousingExpertModeUIDocumentation.lua",
    "HousingNeighborhoodUIDocumentation.lua",
    "HouseExteriorUIDocumentation.lua",
    "HouseExteriorConstantsDocumentation.lua",
    "HousingCatalogConstantsDocumentation.lua",
    "HousingCatalogSearcherAPIDocumentation.lua",
    "NeighborhoodInitiativesConstantsDocumentation.lua",
]

@dataclass
class LuaField:
    name: str
    field_type: str
    nilable: bool = False
    documentation: List[str] = field(default_factory=list)
    inner_type: Optional[str] = None
    enum_value: Optional[int] = None
    default: Optional[Any] = None

@dataclass
class LuaFunction:
    name: str
    documentation: List[str] = field(default_factory=list)
    arguments: List[LuaField] = field(default_factory=list)
    returns: List[LuaField] = field(default_factory=list)
    secret_arguments: Optional[str] = None

@dataclass
class LuaEvent:
    name: str
    literal_name: str = ""
    unique_event: bool = False
    synchronous_event: bool = False
    payload: List[LuaField] = field(default_factory=list)

@dataclass
class LuaTable:
    name: str
    table_type: str  # Enumeration, Structure, Constants, CallbackType
    documentation: List[str] = field(default_factory=list)
    fields: List[LuaField] = field(default_factory=list)
    num_values: Optional[int] = None
    min_value: Optional[int] = None
    max_value: Optional[int] = None

@dataclass
class LuaDocument:
    name: str = ""
    doc_type: str = ""  # System, ScriptObject
    namespace: Optional[str] = None
    environment: str = "All"
    functions: List[LuaFunction] = field(default_factory=list)
    events: List[LuaEvent] = field(default_factory=list)
    tables: List[LuaTable] = field(default_factory=list)


class LuaTableParser:
    """Parse Lua table definitions into structured data."""

    def __init__(self, content: str):
        self.content = content
        self.pos = 0

    def parse(self) -> LuaDocument:
        """Parse the entire Lua document."""
        doc = LuaDocument()

        # Find the main table
        match = re.search(r'local\s+\w+\s*=\s*\{', self.content)
        if not match:
            return doc

        self.pos = match.end()
        main_table = self._parse_table_content()

        # Extract top-level fields
        doc.name = main_table.get('Name', '')
        doc.doc_type = main_table.get('Type', '')
        doc.namespace = main_table.get('Namespace')
        doc.environment = main_table.get('Environment', 'All')

        # Parse Functions
        if 'Functions' in main_table and isinstance(main_table['Functions'], list):
            for func_data in main_table['Functions']:
                doc.functions.append(self._parse_function(func_data))

        # Parse Events
        if 'Events' in main_table and isinstance(main_table['Events'], list):
            for event_data in main_table['Events']:
                doc.events.append(self._parse_event(event_data))

        # Parse Tables (Enumerations, Structures, Constants, CallbackTypes)
        if 'Tables' in main_table and isinstance(main_table['Tables'], list):
            for table_data in main_table['Tables']:
                doc.tables.append(self._parse_table_definition(table_data))

        return doc

    def _skip_whitespace(self):
        """Skip whitespace and comments."""
        while self.pos < len(self.content):
            if self.content[self.pos:self.pos+2] == '--':
                # Skip to end of line
                while self.pos < len(self.content) and self.content[self.pos] != '\n':
                    self.pos += 1
            elif self.content[self.pos] in ' \t\n\r':
                self.pos += 1
            else:
                break

    def _parse_string(self) -> str:
        """Parse a Lua string (single or double quoted)."""
        quote = self.content[self.pos]
        self.pos += 1
        start = self.pos

        while self.pos < len(self.content):
            if self.content[self.pos] == '\\':
                self.pos += 2  # Skip escaped character
            elif self.content[self.pos] == quote:
                result = self.content[start:self.pos]
                self.pos += 1
                return result
            else:
                self.pos += 1

        return self.content[start:]

    def _parse_value(self) -> Any:
        """Parse a Lua value (string, number, boolean, table, identifier)."""
        self._skip_whitespace()

        if self.pos >= len(self.content):
            return None

        char = self.content[self.pos]

        # String
        if char in '"\'':
            return self._parse_string()

        # Table/array
        if char == '{':
            self.pos += 1
            return self._parse_table_content()

        # Number, boolean, or identifier
        match = re.match(r'[\w.]+', self.content[self.pos:])
        if match:
            value = match.group()
            self.pos += len(value)

            if value == 'true':
                return True
            elif value == 'false':
                return False
            elif value == 'nil':
                return None

            try:
                if '.' in value:
                    return float(value)
                return int(value)
            except ValueError:
                return value

        return None

    def _parse_table_content(self) -> Any:
        """Parse the content of a Lua table (between { and })."""
        self._skip_whitespace()

        # Check if this is an array or a dictionary
        # Look ahead to see if first item has a key
        save_pos = self.pos
        is_array = True

        while self.pos < len(self.content) and self.content[self.pos] not in '}':
            self._skip_whitespace()
            if self.content[self.pos] == '}':
                break

            # Check for key = value pattern
            match = re.match(r'(\w+)\s*=', self.content[self.pos:])
            if match:
                is_array = False
            break

        self.pos = save_pos

        if is_array:
            return self._parse_array()
        else:
            return self._parse_dict()

    def _parse_array(self) -> List[Any]:
        """Parse a Lua array."""
        result = []

        while self.pos < len(self.content):
            self._skip_whitespace()

            if self.content[self.pos] == '}':
                self.pos += 1
                return result

            if self.content[self.pos] == '{':
                self.pos += 1
                result.append(self._parse_table_content())
            else:
                value = self._parse_value()
                if value is not None:
                    result.append(value)

            self._skip_whitespace()
            if self.pos < len(self.content) and self.content[self.pos] == ',':
                self.pos += 1

        return result

    def _parse_dict(self) -> Dict[str, Any]:
        """Parse a Lua dictionary/table."""
        result = {}

        while self.pos < len(self.content):
            self._skip_whitespace()

            if self.content[self.pos] == '}':
                self.pos += 1
                return result

            # Parse key
            match = re.match(r'(\w+)\s*=\s*', self.content[self.pos:])
            if not match:
                # Skip unexpected character
                self.pos += 1
                continue

            key = match.group(1)
            self.pos += match.end()

            # Parse value
            value = self._parse_value()
            result[key] = value

            self._skip_whitespace()
            if self.pos < len(self.content) and self.content[self.pos] == ',':
                self.pos += 1

        return result

    def _parse_function(self, data: Dict[str, Any]) -> LuaFunction:
        """Parse a function definition."""
        func = LuaFunction(name=data.get('Name', ''))

        if 'Documentation' in data:
            func.documentation = data['Documentation'] if isinstance(data['Documentation'], list) else [data['Documentation']]

        if 'SecretArguments' in data:
            func.secret_arguments = data['SecretArguments']

        if 'Arguments' in data and isinstance(data['Arguments'], list):
            for arg in data['Arguments']:
                func.arguments.append(self._parse_field(arg))

        if 'Returns' in data and isinstance(data['Returns'], list):
            for ret in data['Returns']:
                func.returns.append(self._parse_field(ret))

        return func

    def _parse_event(self, data: Dict[str, Any]) -> LuaEvent:
        """Parse an event definition."""
        event = LuaEvent(name=data.get('Name', ''))
        event.literal_name = data.get('LiteralName', '')
        event.unique_event = data.get('UniqueEvent', False)
        event.synchronous_event = data.get('SynchronousEvent', False)

        if 'Payload' in data and isinstance(data['Payload'], list):
            for field_data in data['Payload']:
                event.payload.append(self._parse_field(field_data))

        return event

    def _parse_table_definition(self, data: Dict[str, Any]) -> LuaTable:
        """Parse a table (Enumeration, Structure, Constants, CallbackType)."""
        table = LuaTable(
            name=data.get('Name', ''),
            table_type=data.get('Type', '')
        )

        if 'Documentation' in data:
            table.documentation = data['Documentation'] if isinstance(data['Documentation'], list) else [data['Documentation']]

        table.num_values = data.get('NumValues')
        table.min_value = data.get('MinValue')
        table.max_value = data.get('MaxValue')

        if 'Fields' in data and isinstance(data['Fields'], list):
            for field_data in data['Fields']:
                table.fields.append(self._parse_field(field_data))

        return table

    def _parse_field(self, data: Dict[str, Any]) -> LuaField:
        """Parse a field definition."""
        field_obj = LuaField(
            name=data.get('Name', ''),
            field_type=data.get('Type', '')
        )

        field_obj.nilable = data.get('Nilable', False)
        field_obj.inner_type = data.get('InnerType')
        field_obj.enum_value = data.get('EnumValue')
        field_obj.default = data.get('Default')

        if 'Documentation' in data:
            field_obj.documentation = data['Documentation'] if isinstance(data['Documentation'], list) else [data['Documentation']]

        return field_obj


class MarkdownGenerator:
    """Generate markdown documentation from parsed Lua documents."""

    def __init__(self):
        self.all_documents: List[LuaDocument] = []
        self.tainted_functions: Dict[str, List[tuple]] = {}  # restriction -> [(namespace, func_name)]

    def generate_header(self) -> str:
        """Generate the markdown file header."""
        return """# WoW Housing API Reference

Generated from Townlong Yak FrameXML documentation
Source: townlong-yak.com/framexml/live

---

"""

    def generate_section(self, doc: LuaDocument, filename: str) -> str:
        """Generate markdown section for a single document."""
        lines = []

        # Section header
        lines.append(f"## {doc.name or filename.replace('.lua', '')} (from {filename})")
        lines.append(f"- **Type**: {doc.doc_type or 'Unknown'}")
        if doc.namespace:
            lines.append(f"- **Namespace**: {doc.namespace}")
        lines.append(f"- **Environment**: {doc.environment}")
        lines.append("")

        # Track tainted functions
        namespace = doc.namespace or doc.name

        # Functions
        if doc.functions:
            lines.append("### Functions")
            lines.append("")

            for func in doc.functions:
                lines.append(f"#### {func.name}")

                if func.secret_arguments:
                    lines.append(f"- **Tainted**: Yes ({func.secret_arguments})")
                    # Track for summary
                    if func.secret_arguments not in self.tainted_functions:
                        self.tainted_functions[func.secret_arguments] = []
                    self.tainted_functions[func.secret_arguments].append((namespace, func.name))
                else:
                    lines.append("- **Tainted**: No")

                if func.documentation:
                    doc_str = "; ".join(func.documentation)
                    lines.append(f"- **Doc**: \"{doc_str}\"")

                if func.arguments:
                    args = []
                    for arg in func.arguments:
                        arg_str = f"{arg.name} ({arg.field_type}"
                        if arg.inner_type:
                            arg_str += f"<{arg.inner_type}>"
                        if arg.nilable:
                            arg_str += ", nilable"
                        arg_str += ")"
                        if arg.documentation:
                            arg_str += f" — {'; '.join(arg.documentation)}"
                        args.append(arg_str)
                    lines.append(f"- **Args**: {', '.join(args)}")

                if func.returns:
                    rets = []
                    for ret in func.returns:
                        ret_str = f"{ret.name} ({ret.field_type}"
                        if ret.inner_type:
                            ret_str += f"<{ret.inner_type}>"
                        if ret.nilable:
                            ret_str += ", nilable"
                        ret_str += ")"
                        if ret.documentation:
                            ret_str += f" — {'; '.join(ret.documentation)}"
                        rets.append(ret_str)
                    lines.append(f"- **Returns**: {', '.join(rets)}")

                lines.append("")

        # Enumerations
        enums = [t for t in doc.tables if t.table_type == "Enumeration"]
        if enums:
            lines.append("### Enumerations")
            lines.append("")

            for enum in enums:
                lines.append(f"#### {enum.name}")
                if enum.documentation:
                    lines.append(f"*{'; '.join(enum.documentation)}*")
                    lines.append("")

                lines.append("| Name | Value | Documentation |")
                lines.append("|------|-------|---------------|")

                for field_obj in enum.fields:
                    doc_str = "; ".join(field_obj.documentation) if field_obj.documentation else ""
                    lines.append(f"| {field_obj.name} | {field_obj.enum_value} | {doc_str} |")

                lines.append("")

        # Structures
        structs = [t for t in doc.tables if t.table_type == "Structure"]
        if structs:
            lines.append("### Structures")
            lines.append("")

            for struct in structs:
                lines.append(f"#### {struct.name}")
                if struct.documentation:
                    lines.append(f"*{'; '.join(struct.documentation)}*")
                    lines.append("")

                lines.append("| Field | Type | Nilable | Documentation |")
                lines.append("|-------|------|---------|---------------|")

                for field_obj in struct.fields:
                    type_str = field_obj.field_type
                    if field_obj.inner_type:
                        type_str += f"<{field_obj.inner_type}>"
                    nilable_str = "Yes" if field_obj.nilable else "No"
                    doc_str = "; ".join(field_obj.documentation) if field_obj.documentation else ""
                    if field_obj.default is not None:
                        doc_str = f"Default: {field_obj.default}. {doc_str}"
                    lines.append(f"| {field_obj.name} | {type_str} | {nilable_str} | {doc_str} |")

                lines.append("")

        # Constants
        constants = [t for t in doc.tables if t.table_type == "Constants"]
        if constants:
            lines.append("### Constants")
            lines.append("")

            for const in constants:
                lines.append(f"#### {const.name}")
                if const.documentation:
                    lines.append(f"*{'; '.join(const.documentation)}*")
                    lines.append("")

                lines.append("| Name | Type | Value |")
                lines.append("|------|------|-------|")

                for field_obj in const.fields:
                    value = field_obj.enum_value if field_obj.enum_value is not None else field_obj.default or ""
                    lines.append(f"| {field_obj.name} | {field_obj.field_type} | {value} |")

                lines.append("")

        # Events
        if doc.events:
            lines.append("### Events")
            lines.append("")

            for event in doc.events:
                lines.append(f"#### {event.literal_name or event.name}")
                flags = []
                if event.unique_event:
                    flags.append("UniqueEvent")
                if event.synchronous_event:
                    flags.append("SynchronousEvent")
                if flags:
                    lines.append(f"*{', '.join(flags)}*")

                if event.payload:
                    lines.append("")
                    lines.append("| Field | Type | Nilable |")
                    lines.append("|-------|------|---------|")

                    for field_obj in event.payload:
                        type_str = field_obj.field_type
                        if field_obj.inner_type:
                            type_str += f"<{field_obj.inner_type}>"
                        nilable_str = "Yes" if field_obj.nilable else "No"
                        lines.append(f"| {field_obj.name} | {type_str} | {nilable_str} |")

                lines.append("")

        # CallbackTypes
        callbacks = [t for t in doc.tables if t.table_type == "CallbackType"]
        if callbacks:
            lines.append("### Callback Types")
            lines.append("")
            for cb in callbacks:
                lines.append(f"- **{cb.name}**")
            lines.append("")

        lines.append("---")
        lines.append("")

        return "\n".join(lines)

    def generate_analysis(self) -> str:
        """Generate the Homestead Addon Analysis section."""
        lines = []

        lines.append("# Homestead Addon Analysis")
        lines.append("")
        lines.append("## Key Findings")
        lines.append("")

        # 1. Full Catalog Enumeration
        lines.append("### 1. Full Catalog Enumeration")
        lines.append("")
        lines.append("**Can we enumerate ALL decor items (including unowned) programmatically?**")
        lines.append("")
        lines.append("**YES** - The `HousingCatalogSearcherAPI` ScriptObject provides comprehensive enumeration:")
        lines.append("")
        lines.append("- `CreateCatalogSearcher()` (C_HousingCatalog) — Creates a new searcher instance (NO taint restriction)")
        lines.append("- `SetUncollected(isActive)` — Include unowned items in search (tainted: AllowedWhenUntainted)")
        lines.append("- `SetCollected(isActive)` — Include owned items in search (tainted)")
        lines.append("- `RunSearch()` — Execute the search (NO taint restriction)")
        lines.append("- `GetCatalogSearchResults()` — Get matching entry IDs (NO taint restriction)")
        lines.append("- `GetAllSearchItems()` — Get ALL items being searched, not just results (NO taint restriction)")
        lines.append("")
        lines.append("**Critical insight**: The Searcher's getter functions (`GetCatalogSearchResults`, `GetAllSearchItems`, ")
        lines.append("`IsUncollectedActive`, etc.) are NOT tainted, only the setters are. This means:")
        lines.append("1. Blizzard's UI sets up the searcher (calls SetUncollected, etc.)")
        lines.append("2. Addon code can READ the results without taint issues")
        lines.append("")
        lines.append("**However**: `GetCatalogEntryInfo()` and related functions ARE tainted, so getting detailed ")
        lines.append("info about the entries returned by the searcher may still require UI interaction.")
        lines.append("")

        # 2. Source/Vendor Data
        lines.append("### 2. Source/Vendor Data")
        lines.append("")
        lines.append("**Can we get source or vendor information for items we don't own?**")
        lines.append("")
        lines.append("**NO** - The API does NOT provide source/vendor information. Key structures examined:")
        lines.append("")
        lines.append("- `HousingCatalogEntryInfo` — Contains: entryID, entryType, entrySubtype, recordID, ")
        lines.append("  quantity fields, categoryID, subcategoryID. **NO source field**.")
        lines.append("- `HousingDecorInstanceInfo` — Instance info for placed decor. **NO source field**.")
        lines.append("- `HousingPreviewItemData` — Preview data. **NO vendor/source field**.")
        lines.append("")
        lines.append("**Conclusion**: Vendor/source mapping must come from external data (Wowhead scraping, ")
        lines.append("manual database like DecorSources.lua) or in-game vendor scanning.")
        lines.append("")

        # 3. Taint Blockers
        lines.append("### 3. Taint Blockers")
        lines.append("")
        lines.append("**Which useful functions have SecretArguments restrictions?**")
        lines.append("")
        lines.append("Most C_HousingCatalog functions are tainted with `AllowedWhenUntainted`. This means:")
        lines.append("- They work when called from Blizzard UI code")
        lines.append("- They fail/error when called from addon code (tainted execution)")
        lines.append("")
        lines.append("**Critical tainted functions for Homestead:**")
        lines.append("- `GetCatalogEntryInfo(entryID)` — Can't get item details from addon code")
        lines.append("- `GetCatalogEntryInfoByItem(itemInfo, tryGetOwnedInfo)` — Can't lookup by item link")
        lines.append("- `GetCatalogEntryInfoByRecordID(type, recordID, tryGetOwnedInfo)` — Can't lookup by ID")
        lines.append("- `GetCatalogCategoryInfo(categoryID)` — Can't get category names")
        lines.append("- `GetCatalogSubcategoryInfo(subcategoryID)` — Can't get subcategory names")
        lines.append("")
        lines.append("**Untainted functions (addon-usable):**")
        lines.append("- `CreateCatalogSearcher()` — Can create searcher instances!")
        lines.append("- `GetAllFilterTagGroups()` — Can get filter tag info")
        lines.append("- `GetCartSizeLimit()` — Cart limit")
        lines.append("- `GetDecorMaxOwnedCount()` / `GetDecorTotalOwnedCount()` — Ownership counts")
        lines.append("- Searcher instance getters: `GetCatalogSearchResults()`, `GetAllSearchItems()`, etc.")
        lines.append("")
        lines.append("**Can addon code realistically use the SearcherAPI?**")
        lines.append("")
        lines.append("**Partially**. Addon can:")
        lines.append("1. Create a searcher via `C_HousingCatalog.CreateCatalogSearcher()`")
        lines.append("2. Call `RunSearch()` (untainted)")
        lines.append("3. Call `GetCatalogSearchResults()` to get entry IDs (untainted)")
        lines.append("")
        lines.append("Addon **cannot** directly:")
        lines.append("- Call `SetUncollected()`, `SetCollected()`, etc. (tainted)")
        lines.append("- Call `GetCatalogEntryInfo()` to get details about entries (tainted)")
        lines.append("")
        lines.append("**Workaround potential**: If the player opens the Housing Catalog UI with ")
        lines.append("\"Show Uncollected\" enabled, the addon might be able to read the results ")
        lines.append("from that searcher state.")
        lines.append("")

        # 4. Missing Events
        lines.append("### 4. Missing Events")
        lines.append("")
        lines.append("**Are there housing events we should be listening to?**")
        lines.append("")
        lines.append("Key events from the documentation:")
        lines.append("")
        lines.append("**Catalog/Storage Events:**")
        lines.append("- `HOUSING_CATALOG_CATEGORY_UPDATED` — Category changed")
        lines.append("- `HOUSING_CATALOG_SUBCATEGORY_UPDATED` — Subcategory changed")
        lines.append("- `HOUSING_STORAGE_UPDATED` — Storage changed (UniqueEvent)")
        lines.append("- `HOUSING_STORAGE_ENTRY_UPDATED` — Specific entry changed")
        lines.append("- `HOUSING_REFUND_LIST_UPDATED` — Refund list changed")
        lines.append("")
        lines.append("**Preview/Cart Events:**")
        lines.append("- `HOUSING_DECOR_ADD_TO_PREVIEW_LIST` — Item added to preview")
        lines.append("- `HOUSING_DECOR_PREVIEW_LIST_UPDATED` — Preview list changed")
        lines.append("- `HOUSING_DECOR_PREVIEW_LIST_REMOVE_FROM_WORLD` — Preview item removed")
        lines.append("")
        lines.append("**Layout/Editor Events:**")
        lines.append("- `HOUSING_LAYOUT_ENTER_EDIT_MODE` — Entered edit mode")
        lines.append("- `HOUSING_LAYOUT_EXIT_EDIT_MODE` — Exited edit mode")
        lines.append("- `HOUSING_LAYOUT_DECOR_PLACED` — Decor placed in world")
        lines.append("- `HOUSING_LAYOUT_DECOR_RETURNED_TO_STORAGE` — Decor returned to storage")
        lines.append("- `HOUSING_LAYOUT_DECOR_SELECTED` / `DESELECTED` — Selection changed")
        lines.append("")
        lines.append("**Recommended additions for Homestead:**")
        lines.append("- `HOUSING_STORAGE_UPDATED` — Refresh ownership cache when storage changes")
        lines.append("- `HOUSING_STORAGE_ENTRY_UPDATED` — Update specific entry in cache")
        lines.append("- `HOUSING_LAYOUT_DECOR_PLACED` / `RETURNED_TO_STORAGE` — Track placement changes")
        lines.append("")

        # 5. Item-to-Vendor Mapping
        lines.append("### 5. Item-to-Vendor Mapping")
        lines.append("")
        lines.append("**Is there any API path from item/recordID to vendor/merchant data?**")
        lines.append("")
        lines.append("**NO** - There is no connection between Housing APIs and Merchant APIs.")
        lines.append("")
        lines.append("The `C_MerchantFrame` API provides:")
        lines.append("- `GetMerchantItemInfo(index)` — Returns: name, texture, price, stackCount, etc.")
        lines.append("- `GetMerchantItemLink(index)` — Returns item link")
        lines.append("- `GetMerchantItemID(index)` — Returns itemID")
        lines.append("")
        lines.append("But there's no:")
        lines.append("- API to query \"which vendors sell this item\"")
        lines.append("- Connection from `HousingCatalogEntryInfo` to merchant data")
        lines.append("- Source field in any housing structure")
        lines.append("")
        lines.append("**Conclusion**: Vendor scanning remains necessary. The API does not provide ")
        lines.append("any vendor/source information for decor items.")
        lines.append("")

        # 6. Unowned Item Data
        lines.append("### 6. Unowned Item Data")
        lines.append("")
        lines.append("**What data fields are available for items the player doesn't own?**")
        lines.append("")
        lines.append("From `HousingCatalogEntryInfo` structure:")
        lines.append("")
        lines.append("| Field | Available for Unowned? | Notes |")
        lines.append("|-------|------------------------|-------|")
        lines.append("| entryID | Yes | HousingCatalogEntryID |")
        lines.append("| entryType | Yes | HousingCatalogEntryType enum |")
        lines.append("| entrySubtype | **No** | 1 = Unowned, other values = owned variants |")
        lines.append("| recordID | Yes | Internal record ID |")
        lines.append("| totalQuantity | No | Only for owned |")
        lines.append("| availableQuantity | No | Only for owned |")
        lines.append("| placedQuantity | No | Only for owned |")
        lines.append("| categoryID | Yes | Category reference |")
        lines.append("| subcategoryID | Yes | Subcategory reference |")
        lines.append("")
        lines.append("**Note**: Getting the actual item **name** and **icon** requires calling ")
        lines.append("`GetCatalogEntryInfo()` which is tainted. The entry ID alone doesn't provide display info.")
        lines.append("")

        # 7. Market Cart / Merchant Integration
        lines.append("### 7. Market Cart / Merchant Integration")
        lines.append("")
        lines.append("**Do HousingMarketCart or MerchantFrame APIs reveal vendor-decor relationships?**")
        lines.append("")
        lines.append("**No direct relationship.** Analysis:")
        lines.append("")
        lines.append("- `HousingMarketCartInfo` structure exists but relates to the in-game housing market ")
        lines.append("  (player housing shop), not vendors")
        lines.append("- `C_MerchantFrame` API is generic for all merchants, not housing-specific")
        lines.append("- No API connects merchant NPCs to decor items")
        lines.append("")
        lines.append("The housing \"Market Cart\" is separate from NPC vendors — it's the shopping cart ")
        lines.append("in the Housing Catalog UI for purchasing from the in-game shop.")
        lines.append("")

        # 8. Searcher Instance
        lines.append("### 8. Searcher Instance")
        lines.append("")
        lines.append("**How is the HousingCatalogSearcherAPI ScriptObject instantiated?**")
        lines.append("")
        lines.append("```lua")
        lines.append("-- Create a new searcher instance")
        lines.append("local searcher = C_HousingCatalog.CreateCatalogSearcher()")
        lines.append("")
        lines.append("-- The searcher is a ScriptObject with methods like:")
        lines.append("searcher:SetUncollected(true)     -- TAINTED")
        lines.append("searcher:SetCollected(true)       -- TAINTED")
        lines.append("searcher:RunSearch()              -- Untainted")
        lines.append("local results = searcher:GetCatalogSearchResults()  -- Untainted")
        lines.append("```")
        lines.append("")
        lines.append("**Can addons create or access one?**")
        lines.append("")
        lines.append("**Yes**, `CreateCatalogSearcher()` is NOT tainted. Addons can create instances.")
        lines.append("")
        lines.append("**However**, the configuration methods (`SetUncollected`, `SetCollected`, etc.) ARE ")
        lines.append("tainted, so the addon-created searcher would have default filter settings.")
        lines.append("")
        lines.append("**Potential workaround**: Hook into Blizzard's Housing Catalog frame to access ")
        lines.append("their pre-configured searcher instance.")
        lines.append("")

        # Taint Summary
        lines.append("## Taint Summary")
        lines.append("")
        lines.append("All functions with `SecretArguments = \"AllowedWhenUntainted\"`:")
        lines.append("")

        for restriction, funcs in sorted(self.tainted_functions.items()):
            lines.append(f"### {restriction}")
            lines.append("")
            for namespace, func_name in sorted(funcs):
                lines.append(f"- `{namespace}.{func_name}`")
            lines.append("")

        # Type Cross-Reference
        lines.append("## Type Cross-Reference")
        lines.append("")

        lines.append("### What returns HousingCatalogEntryID?")
        lines.append("- `HousingCatalogSearcher:GetCatalogSearchResults()` — Returns table<HousingCatalogEntryID>")
        lines.append("- `HousingCatalogSearcher:GetAllSearchItems()` — Returns table<HousingCatalogEntryID>")
        lines.append("- `HousingCatalogEntryInfo.entryID` — Field on the info structure")
        lines.append("")

        lines.append("### What returns decor source info?")
        lines.append("**Nothing.** No API returns source/vendor information.")
        lines.append("")

        lines.append("### What accepts recordID as input?")
        lines.append("- `C_HousingCatalog.GetCatalogEntryInfoByRecordID(entryType, recordID, tryGetOwnedInfo)` — Tainted")
        lines.append("- `C_HousingCatalog.GetCatalogEntryRefundTimeStampByRecordID(entryType, recordID)` — Tainted")
        lines.append("")

        lines.append("### What connects catalog entries to merchant/vendor data?")
        lines.append("**Nothing.** The Housing and Merchant APIs are completely separate.")
        lines.append("")

        # Recommended API Strategy
        lines.append("## Recommended API Strategy for Homestead")
        lines.append("")

        lines.append("### What Homestead should consider adopting")
        lines.append("")
        lines.append("1. **New Events**: Register for these housing events:")
        lines.append("   - `HOUSING_STORAGE_UPDATED` — Refresh ownership cache")
        lines.append("   - `HOUSING_STORAGE_ENTRY_UPDATED` — Update specific entry")
        lines.append("   - `HOUSING_LAYOUT_DECOR_PLACED` — Track when items are placed")
        lines.append("   - `HOUSING_LAYOUT_DECOR_RETURNED_TO_STORAGE` — Track when items are returned")
        lines.append("")
        lines.append("2. **Searcher Experimentation**: Test if addon code can:")
        lines.append("   - Create a searcher and call `RunSearch()` with default settings")
        lines.append("   - Read results after player interacts with Housing Catalog UI")
        lines.append("   - Hook Blizzard's Housing Catalog frame to access their searcher")
        lines.append("")
        lines.append("3. **Ownership Detection**: Use these untainted functions:")
        lines.append("   - `C_HousingCatalog.GetDecorTotalOwnedCount()` — Already in use")
        lines.append("   - `C_HousingCatalog.GetDecorMaxOwnedCount()` — Capacity checking")
        lines.append("")

        lines.append("### What limitations exist")
        lines.append("")
        lines.append("1. **Taint**: Most useful `GetCatalogEntryInfo*` functions are tainted")
        lines.append("2. **No Source Data**: API provides NO vendor/source information")
        lines.append("3. **Collection-Gating**: `entrySubtype = 1` indicates unowned, limited data available")
        lines.append("4. **Category Info**: `GetCatalogCategoryInfo()` is tainted, can't get category names")
        lines.append("")

        lines.append("### Whether vendor scanning can be supplemented or replaced")
        lines.append("")
        lines.append("**Cannot be replaced.** The API does not provide:")
        lines.append("- Which vendors sell which items")
        lines.append("- Item prices at vendors")
        lines.append("- Vendor locations")
        lines.append("- Source information of any kind")
        lines.append("")
        lines.append("**Vendor scanning remains essential.** The Housing API is designed for catalog ")
        lines.append("browsing and placement, not acquisition tracking.")
        lines.append("")
        lines.append("**Could be supplemented** by using `HOUSING_STORAGE_UPDATED` events to refresh ")
        lines.append("the ownership cache more proactively, rather than relying solely on CatalogScanner.")
        lines.append("")

        lines.append("### Any new features these APIs would enable")
        lines.append("")
        lines.append("1. **Better Ownership Tracking**: `HOUSING_STORAGE_*` events provide real-time updates")
        lines.append("2. **Placement Tracking**: Know when items are placed vs. in storage")
        lines.append("3. **Category Filtering**: Could potentially filter owned items by category")
        lines.append("4. **Dye Information**: `HousingDecorDyeSlot` structure provides dye slot data")
        lines.append("5. **Preview Integration**: Events for preview list could enhance UI")
        lines.append("")
        lines.append("**Bottom line**: The Housing API is useful for ownership and placement tracking, ")
        lines.append("but provides zero information about where items come from. The static vendor ")
        lines.append("database and in-game scanning remain the only way to build vendor-item mappings.")
        lines.append("")

        return "\n".join(lines)


def main():
    """Main entry point."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    zip_path = os.path.join(script_dir, "HousingAPIs.zip")
    output_path = os.path.join(script_dir, "..", "HOUSING_API_REFERENCE.md")

    if not os.path.exists(zip_path):
        print(f"Error: {zip_path} not found")
        return 1

    generator = MarkdownGenerator()

    # Write header
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(generator.generate_header())

    print(f"Processing files from {zip_path}")
    print(f"Output: {output_path}")
    print()

    # Process files by tier
    all_files = TIER_1_FILES + TIER_2_FILES + TIER_3_FILES

    with zipfile.ZipFile(zip_path) as z:
        available_files = set(z.namelist())

        for tier_num, tier_files in enumerate([TIER_1_FILES, TIER_2_FILES, TIER_3_FILES], 1):
            print(f"=== Tier {tier_num} ===")

            for filename in tier_files:
                if filename not in available_files:
                    print(f"  SKIP: {filename} (not in zip)")
                    continue

                print(f"  Processing: {filename}")

                try:
                    content = z.read(filename).decode('utf-8')
                    parser = LuaTableParser(content)
                    doc = parser.parse()
                    generator.all_documents.append(doc)

                    # Append to output file
                    section = generator.generate_section(doc, filename)
                    with open(output_path, 'a', encoding='utf-8') as f:
                        f.write(section)

                    # Stats
                    stats = []
                    if doc.functions:
                        stats.append(f"{len(doc.functions)} functions")
                    if doc.events:
                        stats.append(f"{len(doc.events)} events")
                    if doc.tables:
                        stats.append(f"{len(doc.tables)} tables")
                    print(f"    -> {', '.join(stats) if stats else 'empty'}")

                except Exception as e:
                    print(f"    ERROR: {e}")

            print()

    # Append analysis section
    print("Generating analysis section...")
    analysis = generator.generate_analysis()
    with open(output_path, 'a', encoding='utf-8') as f:
        f.write(analysis)

    print(f"\nDone! Output written to {output_path}")

    # Summary
    total_funcs = sum(len(d.functions) for d in generator.all_documents)
    total_events = sum(len(d.events) for d in generator.all_documents)
    total_tables = sum(len(d.tables) for d in generator.all_documents)
    total_tainted = sum(len(funcs) for funcs in generator.tainted_functions.values())

    print(f"\nSummary:")
    print(f"  Files processed: {len(generator.all_documents)}")
    print(f"  Total functions: {total_funcs} ({total_tainted} tainted)")
    print(f"  Total events: {total_events}")
    print(f"  Total tables: {total_tables}")

    return 0


if __name__ == "__main__":
    exit(main())

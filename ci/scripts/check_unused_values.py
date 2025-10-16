#!/usr/bin/env python3
"""
Validation script to check for unused values in Helm chart values.yaml file.

This script analyzes the dify Helm chart to identify values defined in values.yaml
that are not referenced in any of the template files. It helps to keep the chart
clean by identifying obsolete or unused configuration parameters.

The script automatically skips checking values under configurable sections.
By default, it skips:
- .Values.redis (managed by dependency charts)
- .Values.postgresql (managed by dependency charts)
- .Values.externalSecret (managed by ExternalSecrets)
- .Values.weaviate (managed by dependency charts)

Usage:
    python3 check_unused_values.py [--skip-section section1] [--skip-section section2] [...]

Example:
    python3 check_unused_values.py  # Uses default skip sections
    python3 check_unused_values.py --skip-section redis --skip-section postgresql  # Custom skip sections
"""

import yaml
import re
import argparse
from pathlib import Path

# Default sections to skip
DEFAULT_SKIP_SECTIONS = ['redis', 'postgresql', 'externalSecret', 'weaviate']

def load_values(file_path):
    """Load values from values.yaml file"""
    with open(file_path, 'r') as f:
        return yaml.safe_load(f)

def extract_template_references(template_dir):
    """Extract all .Values references from template files"""
    references = set()
    template_path = Path(template_dir)
    
    # Regular expression to match .Values references
    # This pattern captures more complex references including those with index operations
    values_pattern = r'\.Values\.([a-zA-Z0-9_\.]+)'
    
    # Walk through all template files
    for template_file in template_path.rglob('*'):
        if template_file.is_file() and template_file.suffix in ['.yaml', '.tpl', '.txt']:
            try:
                with open(template_file, 'r') as f:
                    content = f.read()
                    matches = re.findall(values_pattern, content)
                    for match in matches:
                        references.add(match)
                        
                    # Also look for indirect references with "include" statements
                    include_pattern = r'include\s+["\']dify\.([a-zA-Z0-9_\.]+)["\']'
                    include_matches = re.findall(include_pattern, content)
                    for match in include_matches:
                        references.add(match)
            except Exception as e:
                print(f"Warning: Could not read {template_file}: {e}")
    
    return references

def flatten_dict(d, parent_key='', sep='.'):
    """Flatten nested dictionary"""
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def should_skip_key(key, skip_sections):
    """Check if a key should be skipped based on the skip sections"""
    key_parts = key.split('.')
    if key_parts[0] in skip_sections:
        return True
    return False

def is_value_referenced(key, references):
    """Check if a value key is referenced in the templates"""
    # Direct reference
    if key in references:
        return True
    
    # Partial path references
    key_parts = key.split('.')
    for i in range(len(key_parts)):
        partial_key = '.'.join(key_parts[:i+1])
        if partial_key in references:
            return True
    
    # Check if any reference starts with this key path
    for ref in references:
        if ref.startswith(key + '.'):
            return True
    
    # Special case: check if there are generic references to parent structures
    # For example, if we check "weaviate.image" but templates reference the whole "weaviate" object
    for ref in references:
        if key.startswith(ref + '.'):
            return True
            
    return False

def find_unused_values(values_file, template_dir, skip_sections):
    """Find values defined in values.yaml that are not referenced in templates"""
    # Load values
    values = load_values(values_file)
    
    # Remove skipped sections from values
    filtered_values = {}
    for key, value in values.items():
        if key not in skip_sections:
            filtered_values[key] = value
    
    # Flatten values (excluding skipped sections)
    flat_values = flatten_dict(filtered_values)
    
    # Extract references from templates
    references = extract_template_references(template_dir)
    
    # Find unused values
    unused_values = []
    for key in flat_values.keys():
        if not is_value_referenced(key, references):
            unused_values.append(key)
    
    return unused_values

def main():
    parser = argparse.ArgumentParser(description='Find unused values in Helm chart')
    parser.add_argument('--skip-section', action='append', dest='skip_sections',
                        help='Sections to skip (can be used multiple times). '
                             'Default: redis, postgresql, externalSecret, weaviate')
    args = parser.parse_args()
    
    # Determine skip sections
    skip_sections = args.skip_sections if args.skip_sections else DEFAULT_SKIP_SECTIONS
    
    chart_dir = Path(__file__).parent.parent.parent / 'charts' / 'dify'
    values_file = chart_dir / 'values.yaml'
    template_dir = chart_dir / 'templates'
    
    if not values_file.exists():
        print(f"Error: {values_file} not found")
        return 1
    
    if not template_dir.exists():
        print(f"Error: {template_dir} not found")
        return 1
    
    unused_values = find_unused_values(values_file, template_dir, skip_sections)
    
    if unused_values:
        print(f"Unused values found in values.yaml (not referenced in templates, skipping sections: {', '.join(skip_sections)}):")
        for value in sorted(unused_values):
            print(f"  - {value}")
        print(f"\nTotal unused values: {len(unused_values)}")
        print("\nThese values are defined in values.yaml but not referenced in any template files.")
        print("Consider removing them to keep the chart clean and maintainable.")
        return 1
    else:
        print(f"No unused values found. All defined values are referenced in templates (skipping sections: {', '.join(skip_sections)}).")
        return 0

if __name__ == "__main__":
    exit(main())
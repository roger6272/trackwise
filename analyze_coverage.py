#!/usr/bin/env python3
"""
Analyze code coverage from lcov.info file for the Items feature.
"""

import re
from pathlib import Path
from collections import defaultdict

def parse_lcov(lcov_file):
    """Parse lcov.info file and extract coverage data."""
    coverage_data = []
    current_file = None
    current_lf = 0
    current_lh = 0

    with open(lcov_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('SF:'):
                current_file = line[3:].replace('\\', '/')
            elif line.startswith('LF:'):
                current_lf = int(line[3:])
            elif line.startswith('LH:'):
                current_lh = int(line[3:])
            elif line == 'end_of_record' and current_file:
                coverage_data.append({
                    'file': current_file,
                    'lines_found': current_lf,
                    'lines_hit': current_lh,
                    'coverage': (current_lh / current_lf * 100) if current_lf > 0 else 0
                })
                current_file = None
                current_lf = 0
                current_lh = 0

    return coverage_data

def categorize_files(coverage_data):
    """Categorize files by layer."""
    categories = defaultdict(list)

    for item in coverage_data:
        file_path = item['file']

        if 'features/items' in file_path:
            if '/domain/entities/' in file_path:
                categories['Domain - Entities'].append(item)
            elif '/domain/usecases/' in file_path:
                categories['Domain - Use Cases'].append(item)
            elif '/data/models/' in file_path:
                categories['Data - Models'].append(item)
            elif '/data/repositories/' in file_path:
                categories['Data - Repositories'].append(item)
            elif '/data/datasources/' in file_path:
                categories['Data - Data Sources'].append(item)
            elif '/presentation/bloc/' in file_path:
                categories['Presentation - BLoC'].append(item)
        elif 'lib/core' in file_path:
            categories['Core'].append(item)

    return categories

def calculate_layer_coverage(files):
    """Calculate overall coverage for a layer."""
    total_lf = sum(f['lines_found'] for f in files)
    total_lh = sum(f['lines_hit'] for f in files)
    coverage = (total_lh / total_lf * 100) if total_lf > 0 else 0
    return total_lh, total_lf, coverage

def main():
    lcov_file = Path('coverage/lcov.info')

    if not lcov_file.exists():
        print("Error: coverage/lcov.info not found")
        print("Run: flutter test --coverage")
        return

    print("=" * 80)
    print("ITEMS FEATURE - CODE COVERAGE ANALYSIS")
    print("=" * 80)
    print()

    # Parse coverage data
    coverage_data = parse_lcov(lcov_file)
    categories = categorize_files(coverage_data)

    # Display by layer
    items_total_lh = 0
    items_total_lf = 0

    for category_name in sorted(categories.keys()):
        if category_name == 'Core':
            continue  # Skip core for now

        files = categories[category_name]
        print(f"\n{category_name}")
        print("-" * 80)

        for file_data in sorted(files, key=lambda x: x['file']):
            file_name = file_data['file'].split('/')[-1]
            print(f"  {file_name:<50} {file_data['lines_hit']:>4}/{file_data['lines_found']:<4} ({file_data['coverage']:>5.1f}%)")

        lh, lf, coverage = calculate_layer_coverage(files)
        print(f"  {'-' * 50}")
        print(f"  {'LAYER TOTAL':<50} {lh:>4}/{lf:<4} ({coverage:>5.1f}%)")

        items_total_lh += lh
        items_total_lf += lf

    # Overall Items feature coverage
    if items_total_lf > 0:
        items_coverage = (items_total_lh / items_total_lf * 100)
        print()
        print("=" * 80)
        print(f"ITEMS FEATURE TOTAL:                               {items_total_lh:>4}/{items_total_lf:<4} ({items_coverage:>5.1f}%)")
        print("=" * 80)

    # Core utilities coverage
    if 'Core' in categories:
        print()
        print("\nCore Utilities")
        print("-" * 80)
        for file_data in sorted(categories['Core'], key=lambda x: x['file']):
            file_name = file_data['file'].split('/')[-1]
            print(f"  {file_name:<50} {file_data['lines_hit']:>4}/{file_data['lines_found']:<4} ({file_data['coverage']:>5.1f}%)")

    # Identify low coverage files
    print()
    print("\nFiles with <80% Coverage (Items Feature Only)")
    print("-" * 80)
    low_coverage = [
        f for f in coverage_data
        if 'features/items' in f['file'] and f['coverage'] < 80 and f['lines_found'] > 0
    ]

    if low_coverage:
        for file_data in sorted(low_coverage, key=lambda x: x['coverage']):
            file_name = file_data['file'].split('/')[-1]
            print(f"  {file_name:<50} {file_data['lines_hit']:>4}/{file_data['lines_found']:<4} ({file_data['coverage']:>5.1f}%)")
    else:
        print("  All files have ≥80% coverage! 🎉")

    print()

if __name__ == '__main__':
    main()

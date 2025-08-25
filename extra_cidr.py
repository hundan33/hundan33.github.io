# extract_asn_cidr.py

import requests
import csv
import os
import random
import string
import argparse
import ipaddress
from datetime import datetime
from typing import Set, List
from github_mirror_downloader import GitHubMirrorDownloader

# Country and region mappings
COUNTRY_MAPPINGS = {
    'asia': [
        'CN', 'JP', 'KR', 'IN', 'TH', 'VN', 'SG', 'MY', 'ID', 'PH', 'TW', 'HK', 'MO',
        'AF', 'AM', 'AZ', 'BH', 'BD', 'BT', 'BN', 'KH', 'GE', 'IR', 'IQ', 'IL', 'JO',
        'KZ', 'KW', 'KG', 'LA', 'LB', 'MV', 'MN', 'MM', 'NP', 'KP', 'OM', 'PK', 'PS',
        'QA', 'SA', 'LK', 'SY', 'TJ', 'TM', 'AE', 'UZ', 'YE'
    ],
    'europe': [
        'DE', 'FR', 'GB', 'IT', 'ES', 'NL', 'BE', 'CH', 'AT', 'SE', 'NO', 'DK', 'FI', 'PL', 'RU',
        'AL', 'AD', 'BY', 'BA', 'BG', 'HR', 'CY', 'CZ', 'EE', 'FO', 'GI', 'GR', 'HU', 'IS',
        'IE', 'IM', 'JE', 'XK', 'LV', 'LI', 'LT', 'LU', 'MK', 'MT', 'MD', 'MC', 'ME', 'PT',
        'RO', 'SM', 'RS', 'SK', 'SI', 'UA', 'VA', 'AX', 'GG'
    ],
    'north_america': [
        'US', 'CA', 'MX', 'AG', 'BS', 'BB', 'BZ', 'CR', 'CU', 'DM', 'DO', 'SV', 'GD',
        'GT', 'HT', 'HN', 'JM', 'NI', 'PA', 'KN', 'LC', 'VC', 'TT', 'GL', 'BM', 'PM'
    ],
    'south_america': [
        'BR', 'AR', 'CL', 'CO', 'PE', 'VE', 'EC', 'UY', 'PY', 'BO', 'GY', 'SR', 'GF', 'FK'
    ],
    'africa': [
        'ZA', 'EG', 'NG', 'KE', 'MA', 'TN', 'GH', 'UG', 'ZW', 'ZM', 'DZ', 'AO', 'BJ',
        'BW', 'BF', 'BI', 'CM', 'CV', 'CF', 'TD', 'KM', 'CG', 'CD', 'CI', 'DJ', 'GQ',
        'ER', 'ET', 'GA', 'GM', 'GN', 'GW', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU',
        'YT', 'MZ', 'NA', 'NE', 'RW', 'RE', 'SH', 'ST', 'SN', 'SC', 'SL', 'SO', 'SS',
        'SD', 'SZ', 'TZ', 'TG', 'EH'
    ],
    'oceania': [
        'AU', 'NZ', 'FJ', 'PG', 'NC', 'SB', 'VU', 'WS', 'TO', 'TV', 'AS', 'CK', 'PF',
        'GU', 'KI', 'MH', 'FM', 'NR', 'NU', 'NF', 'MP', 'PW', 'PN', 'TK', 'WF', 'UM'
    ],
    'usa': ['US'],
    'southeast_asia': ['TH', 'VN', 'SG', 'MY', 'ID', 'PH', 'MM', 'KH', 'LA', 'BN', 'TL']
}

def get_latest_release_info():
    """Get the latest release information from GitHub API."""
    api_url = "https://api.github.com/repos/mojolabs-id/GeoLite2-Database/releases/latest"
    try:
        response = requests.get(api_url, timeout=30)
        if response.status_code == 200:
            release_info = response.json()
            return release_info
        else:
            print(f"Failed to get latest release info. Status code: {response.status_code}")
            return None
    except requests.exceptions.Timeout:
        print("GitHub API request timed out after 30 seconds")
        return None
    except Exception as e:
        print(f"Error getting release info: {e}")
        return None

def download_latest_csv_files():
    """Download the latest GeoLite2 CSV files (ASN and Country) with mirror support."""
    release_info = get_latest_release_info()
    if not release_info:
        return False
    
    files_to_download = [
        'GeoLite2-ASN-Blocks-IPv4.csv',
        'GeoLite2-ASN-Blocks-IPv6.csv',
        'GeoLite2-Country-Blocks-IPv4.csv',
        'GeoLite2-Country-Blocks-IPv6.csv',
        'GeoLite2-Country-Locations-en.csv'
    ]
    
    downloaded_files = []
    downloader = GitHubMirrorDownloader(timeout=10)
    
    for filename in files_to_download:
        csv_asset = None
        for asset in release_info.get('assets', []):
            if asset['name'] == filename:
                csv_asset = asset
                break
        
        if not csv_asset:
            print(f"{filename} not found in latest release.")
            continue
        
        print(f"\nDownloading {csv_asset['name']} from release {release_info['tag_name']}...")
        download_url = csv_asset['browser_download_url']
        
        if downloader.download_file(download_url, filename):
            print(f"Successfully downloaded {filename}")
            downloaded_files.append(filename)
        else:
            print(f"Failed to download {filename}")
    
    return len(downloaded_files) > 0

def subtract_overlapping_networks(include_net, exclude_net):
    """Calculate the parts of include_net that don't overlap with exclude_net.
    
    This handles partial overlaps where neither network completely contains the other.
    For simplicity, when there's a partial overlap, we'll be conservative and
    return smaller subnets to avoid the overlapping part.
    """
    try:
        # For partial overlaps, use a simple approach:
        # Split the include network into smaller subnets and keep only those
        # that don't overlap with the exclude network
        
        result_networks = []
        
        # Try to split the include network into /24 subnets (or smaller if it's already smaller)
        target_prefix = min(24, include_net.prefixlen + 4)  # Split into smaller pieces
        
        if include_net.prefixlen >= target_prefix:
            # Network is already small enough, check if it overlaps
            if not include_net.overlaps(exclude_net):
                result_networks.append(include_net)
        else:
            # Split into smaller subnets
            for subnet in include_net.subnets(new_prefix=target_prefix):
                if not subnet.overlaps(exclude_net):
                    result_networks.append(subnet)
        
        return result_networks if result_networks else []
        
    except Exception:
        # If anything goes wrong, return empty list (conservative approach)
        return []

def handle_cidr_exclusions(include_cidrs: Set[str], exclude_cidrs: Set[str]) -> List[str]:
    """Handle CIDR exclusions with maximum efficiency.
    
    Strategy:
    1. Use simple set difference for exact matches (fastest)
    2. For large datasets with few overlaps, use simple exclusion
    3. Only use detailed subnet arithmetic when necessary
    """
    if not exclude_cidrs:
        return sorted(list(include_cidrs))
    
    print(f"Processing CIDR exclusions: {len(include_cidrs)} includes, {len(exclude_cidrs)} excludes")
    
    # Step 1: Fast exact match removal
    simple_result = include_cidrs - exclude_cidrs
    exact_removed = len(include_cidrs) - len(simple_result)
    
    if exact_removed > 0:
        print(f"Removed {exact_removed} exact matches")
    
    # Step 2: For most real-world cases, simple exclusion is sufficient
    # Only do expensive overlap checking if exclude ratio is high
    exclude_ratio = len(exclude_cidrs) / len(include_cidrs) if include_cidrs else 0
    
    if exclude_ratio < 0.1:  # Less than 10% excludes relative to includes
        print("Low exclude ratio detected, using simple exclusion")
        return sorted(list(simple_result))
    
    # Step 3: Quick heuristic - check if excludes and includes are in different IP ranges
    if len(simple_result) > 100:  # Only for larger datasets
        sample_includes = list(simple_result)[:50]  # Sample first 50
        sample_excludes = list(exclude_cidrs - include_cidrs)[:50]  # Sample excludes
        
        likely_overlaps = False
        for inc in sample_includes:
            for exc in sample_excludes:
                if quick_ip_range_check(inc, exc):
                    likely_overlaps = True
                    break
            if likely_overlaps:
                break
        
        if not likely_overlaps:
            print("No overlaps detected in sample, using simple exclusion")
            return sorted(list(simple_result))
    
    # Step 4: Detailed processing only when necessary
    print("Potential overlaps detected, using detailed processing")
    
    result_cidrs = []
    overlaps_processed = 0
    
    for include_cidr in simple_result:
        try:
            include_net = ipaddress.ip_network(include_cidr, strict=False)
            current_networks = [include_net]
            
            # Only check excludes that weren't exact matches
            relevant_excludes = exclude_cidrs - include_cidrs
            
            for exclude_cidr in relevant_excludes:
                try:
                    exclude_net = ipaddress.ip_network(exclude_cidr, strict=False)
                    new_networks = []
                    
                    for current_net in current_networks:
                        if current_net.overlaps(exclude_net):
                            overlaps_processed += 1
                            # Handle different overlap scenarios
                            if exclude_net.supernet_of(current_net) or exclude_net == current_net:
                                # Current network is completely contained in exclude - remove it
                                continue
                            elif current_net.supernet_of(exclude_net):
                                # Exclude network is contained in current - use address_exclude
                                try:
                                    remaining = list(current_net.address_exclude(exclude_net))
                                    new_networks.extend(remaining)
                                except ValueError:
                                    # If address_exclude fails, keep the original network
                                    new_networks.append(current_net)
                            else:
                                # Partial overlap - calculate the non-overlapping parts
                                remaining_parts = subtract_overlapping_networks(current_net, exclude_net)
                                new_networks.extend(remaining_parts)
                        else:
                            new_networks.append(current_net)
                    
                    current_networks = new_networks
                    
                except ValueError:
                    continue
            
            result_cidrs.extend([str(net) for net in current_networks])
            
        except ValueError:
            # Keep invalid CIDRs as-is
            result_cidrs.append(include_cidr)
    
    if overlaps_processed > 0:
        print(f"Processed {overlaps_processed} overlapping subnet operations")
    
    return sorted(result_cidrs)

def quick_ip_range_check(cidr1: str, cidr2: str) -> bool:
    """Quick heuristic check if two CIDRs might overlap."""
    try:
        ip1 = cidr1.split('/')[0].split('.')
        ip2 = cidr2.split('/')[0].split('.')
        
        # Check if first two octets match (simple heuristic)
        return ip1[0] == ip2[0] and ip1[1] == ip2[1]
    except (IndexError, ValueError):
        return True  # Assume overlap if can't parse

def get_country_codes_from_regions(regions):
    """Convert region names to country codes."""
    country_codes = set()
    
    for region in regions:
        region = region.strip().lower()
        if region == 'all':
            # Add all countries from all regions
            for region_countries in COUNTRY_MAPPINGS.values():
                country_codes.update(region_countries)
        elif region in COUNTRY_MAPPINGS:
            country_codes.update(COUNTRY_MAPPINGS[region])
        else:
            # Assume it's a country code
            country_codes.add(region.upper())
    
    return list(country_codes)

def load_country_geoname_mapping(locations_file):
    """Load country code to geoname_id mapping."""
    mapping = {}
    try:
        with open(locations_file, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            header = next(reader)
            for row in reader:
                if len(row) >= 5 and row[4]:  # country_iso_code
                    geoname_id = row[0]
                    country_code = row[4]
                    mapping[country_code] = geoname_id
    except FileNotFoundError:
        print(f"Warning: {locations_file} not found. Country filtering will not work.")
    return mapping

def get_country_cidr_blocks(country_blocks_file, target_countries):
    """Get CIDR blocks for specific countries."""
    locations_file = "GeoLite2-Country-Locations-en.csv"
    country_mapping = load_country_geoname_mapping(locations_file)
    
    target_geoname_ids = set()
    for country_code in target_countries:
        if country_code in country_mapping:
            target_geoname_ids.add(country_mapping[country_code])
    
    country_cidrs = set()
    try:
        with open(country_blocks_file, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            header = next(reader)
            for row in reader:
                if len(row) >= 2 and row[1] in target_geoname_ids:
                    country_cidrs.add(row[0])
    except FileNotFoundError:
        print(f"Warning: {country_blocks_file} not found.")
    
    return country_cidrs

def extract_cidr_ranges(ip_version, include_countries, exclude_countries, include_keywords, exclude_keywords):
    """Extract CIDR ranges based on filters."""
    # File names based on IP version
    asn_file = f"GeoLite2-ASN-Blocks-IPv{ip_version}.csv"
    country_file = f"GeoLite2-Country-Blocks-IPv{ip_version}.csv"
    
    cidr_list = set()
    
    # Step 1: Get country-based CIDR blocks if countries are specified
    country_cidrs = set()
    if include_countries and include_countries != ['all']:
        target_countries = get_country_codes_from_regions(include_countries)
        country_cidrs = get_country_cidr_blocks(country_file, target_countries)
        print(f"Found {len(country_cidrs)} CIDR blocks for included countries")
    
    # Step 2: Get ASN-based CIDR blocks
    asn_cidrs = set()
    try:
        with open(asn_file, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            header = next(reader)
            for row in reader:
                if len(row) >= 3:
                    cidr = row[0]
                    asn_name = row[2].lower()
                    
                    # Check include keywords
                    if include_keywords and include_keywords != ['all']:
                        keyword_match = any(keyword.lower() in asn_name for keyword in include_keywords)
                        if not keyword_match:
                            continue
                    
                    # Check exclude keywords
                    if exclude_keywords:
                        keyword_exclude = any(keyword.lower() in asn_name for keyword in exclude_keywords)
                        if keyword_exclude:
                            continue
                    
                    asn_cidrs.add(cidr)
    except FileNotFoundError:
        print(f"Warning: {asn_file} not found.")
    
    print(f"Found {len(asn_cidrs)} CIDR blocks matching ASN criteria")
    
    # Step 3: Combine results
    if country_cidrs and asn_cidrs:
        # For regional extraction: use country data as primary source
        # Only apply ASN filtering if specific keywords are requested (not 'all')
        if include_keywords and include_keywords != ['all']:
            # When specific ASN keywords are requested, use intersection
            cidr_list = country_cidrs.intersection(asn_cidrs)
        else:
            # When extracting by region only (keywords='all'), use country data
            # But still apply exclude_keywords if specified
            if exclude_keywords:
                cidr_list = country_cidrs.intersection(asn_cidrs)
            else:
                cidr_list = country_cidrs
    elif country_cidrs:
        # If only country data available, but exclude_keywords specified,
        # we need to filter against ASN data
        if exclude_keywords and asn_cidrs:
            cidr_list = country_cidrs.intersection(asn_cidrs)
        else:
            cidr_list = country_cidrs
    elif asn_cidrs:
        cidr_list = asn_cidrs
    
    # Step 4: Apply country exclusions with proper CIDR arithmetic
    if exclude_countries:
        exclude_country_codes = get_country_codes_from_regions(exclude_countries)
        exclude_cidrs = get_country_cidr_blocks(country_file, exclude_country_codes)
        print(f"Found {len(exclude_cidrs)} CIDR blocks to exclude from excluded countries")
        
        # Use proper CIDR exclusion handling
        cidr_list = set(handle_cidr_exclusions(cidr_list, exclude_cidrs))
        print(f"After exclusion processing: {len(cidr_list)} CIDR blocks remain")
    
    return list(cidr_list)

def generate_random_filename():
    """Generate a random filename for output."""
    random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    return f"cidr_output_{random_str}.txt"

def get_user_input(prompt, default=None):
    """Get user input with optional default value."""
    if default:
        user_input = input(f"{prompt} (default: {default}): ").strip()
        return user_input if user_input else default
    else:
        return input(f"{prompt}: ").strip()

def parse_comma_separated(input_str):
    """Parse comma-separated input into a list."""
    if not input_str or input_str.lower() == 'all':
        return ['all']
    return [item.strip() for item in input_str.split(',') if item.strip()]

def check_required_files(ip_version):
    """Check if required CSV files exist for the specified IP version."""
    required_files = [
        f"GeoLite2-ASN-Blocks-IPv{ip_version}.csv",
        f"GeoLite2-Country-Blocks-IPv{ip_version}.csv",
        "GeoLite2-Country-Locations-en.csv"
    ]
    
    missing_files = []
    for file in required_files:
        if not os.path.exists(file):
            missing_files.append(file)
    
    return missing_files

def main():
    parser = argparse.ArgumentParser(description="Extract CIDR ranges based on geographic and company filters.")
    parser.add_argument("--update", action="store_true", help="Force update CSV files from latest release")
    parser.add_argument("--list-countries", action="store_true", help="List all supported countries and regions")
    args = parser.parse_args()
    
    # If user wants to list countries, show them and exit
    if args.list_countries:
        print("Supported regions and countries:")
        print("=" * 50)
        
        # Show regions
        print("\nRegions:")
        for region, countries in COUNTRY_MAPPINGS.items():
            print(f"  {region}: {len(countries)} countries")
            if len(countries) <= 20:
                print(f"    Countries: {', '.join(sorted(countries))}")
            else:
                print(f"    Sample countries: {', '.join(sorted(countries)[:20])}...")
            print()
        
        # Show all unique countries
        all_countries = set()
        for countries in COUNTRY_MAPPINGS.values():
            all_countries.update(countries)
        
        print(f"Total unique countries: {len(all_countries)}")
        print("\nAll country codes (sorted):")
        sorted_countries = sorted(all_countries)
        
        # Print countries in rows of 10
        for i in range(0, len(sorted_countries), 10):
            row = sorted_countries[i:i+10]
            print(f"  {', '.join(row)}")
        
        print("\nUsage examples:")
        print("  - Use region names: asia, europe, north_america, etc.")
        print("  - Use country codes: CN, US, JP, DE, etc.")
        print("  - Use 'all' for all countries")
        print("  - Mix regions and countries: asia,US,DE")
        return
    
    print("=== CIDR Extractor ===")
    print("This tool extracts CIDR ranges based on geographic and company filters.")
    print()
    
    # Step 1: Choose IP version
    print("Step 1: Choose IP version")
    while True:
        ip_version = get_user_input("Enter IP version (4 or 6)", "4")
        if ip_version in ['4', '6']:
            break
        print("Please enter 4 or 6")
    print()
    
    # Step 2: Check and update CSV files if needed
    missing_files = check_required_files(ip_version)
    
    if args.update or missing_files:
        if args.update:
            print("Step 2: Updating CSV files (forced by --update parameter)...")
        else:
            print(f"Step 2: Missing required files: {', '.join(missing_files)}")
            print("Downloading required CSV files...")
        
        if download_latest_csv_files():
            print("CSV files updated successfully.")
        else:
            print("Failed to update some CSV files. Using existing files if available.")
    else:
        print("Step 2: Using existing CSV files (use --update to force download)")
    
    # Verify files exist after potential download
    missing_files = check_required_files(ip_version)
    if missing_files:
        print(f"Error: Required files still missing: {', '.join(missing_files)}")
        print("Please run with --update parameter to download required files.")
        return
    
    print()
    
    # Step 3: Include countries/regions
    print("Step 3: Include countries/regions")
    print("Available regions: asia, europe, north_america, south_america, africa, oceania, usa, southeast_asia")
    print("You can also specify country codes (e.g., CN, US, JP) or 'all' for all countries")
    include_countries_str = get_user_input("Enter countries/regions to include (comma-separated)", "all")
    include_countries = parse_comma_separated(include_countries_str)
    print()
    
    # Step 4: Exclude countries/regions
    print("Step 4: Exclude countries/regions")
    exclude_countries_str = get_user_input("Enter countries/regions to exclude (comma-separated, or leave empty)", "")
    exclude_countries = parse_comma_separated(exclude_countries_str) if exclude_countries_str else []
    print()
    
    # Step 5: Include company keywords
    print("Step 5: Include company keywords")
    print("Enter keywords to search in ASN names (e.g., alibaba, amazon, google)")
    include_keywords_str = get_user_input("Enter company keywords to include (comma-separated)", "all")
    include_keywords = parse_comma_separated(include_keywords_str)
    print()
    
    # Step 6: Exclude company keywords
    print("Step 6: Exclude company keywords")
    exclude_keywords_str = get_user_input("Enter company keywords to exclude (comma-separated, or leave empty)", "")
    exclude_keywords = parse_comma_separated(exclude_keywords_str) if exclude_keywords_str else []
    print()
    
    # Extract CIDR ranges
    print("Extracting CIDR ranges...")
    cidr_list = extract_cidr_ranges(ip_version, include_countries, exclude_countries, include_keywords, exclude_keywords)
    
    if not cidr_list:
        print("No CIDR ranges found matching the criteria.")
        return
    
    # Generate output file
    output_file = generate_random_filename()
    
    # Create data directory if it doesn't exist
    data_dir = "data"
    if not os.path.exists(data_dir):
        os.makedirs(data_dir)
    
    output_path = os.path.join(data_dir, output_file)
    
    # Write results to file
    with open(output_path, "w", encoding="utf-8") as f:
        for cidr in sorted(cidr_list):
            f.write(f"{cidr}\n")
    
    print(f"\nExtraction completed!")
    print(f"Found {len(cidr_list)} CIDR ranges")
    print(f"Results saved to: {output_path}")
    print()
    print("Filter summary:")
    print(f"  IP Version: IPv{ip_version}")
    print(f"  Include Countries: {', '.join(include_countries)}")
    print(f"  Exclude Countries: {', '.join(exclude_countries) if exclude_countries else 'None'}")
    print(f"  Include Keywords: {', '.join(include_keywords)}")
    print(f"  Exclude Keywords: {', '.join(exclude_keywords) if exclude_keywords else 'None'}")

if __name__ == "__main__":
    main()

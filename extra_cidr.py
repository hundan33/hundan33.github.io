# extract_asn_cidr.py

import argparse
import requests
import csv
import os
from datetime import datetime

def get_latest_release_info():
    """Get the latest release information from GitHub API."""
    api_url = "https://api.github.com/repos/mojolabs-id/GeoLite2-Database/releases/latest"
    response = requests.get(api_url)
    if response.status_code == 200:
        release_info = response.json()
        return release_info
    else:
        print(f"Failed to get latest release info. Status code: {response.status_code}")
        return None

def download_latest_asn_csv():
    """Download the latest GeoLite2 ASN CSV file."""
    release_info = get_latest_release_info()
    if not release_info:
        return False
    
    # Find the ASN IPv4 CSV asset
    csv_asset = None
    for asset in release_info.get('assets', []):
        if asset['name'] == 'GeoLite2-ASN-Blocks-IPv4.csv':
            csv_asset = asset
            break
    
    if not csv_asset:
        print("ASN IPv4 CSV file not found in latest release.")
        return False
    
    print(f"Downloading {csv_asset['name']} from release {release_info['tag_name']}...")
    response = requests.get(csv_asset['browser_download_url'])
    if response.status_code == 200:
        with open("GeoLite2-ASN-Blocks-IPv4.csv", "wb") as f:
            f.write(response.content)
        print(f"Downloaded latest ASN CSV file from release {release_info['tag_name']}.")
        return True
    else:
        print(f"Failed to download ASN CSV. Status code: {response.status_code}")
        return False

def extract_cidr_by_keyword(csv_file, keyword, output_file):
    """Extract CIDR ranges from CSV file for rows matching the keyword."""
    cidr_list = []
    with open(csv_file, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)  # Skip header
        for row in reader:
            if len(row) > 2 and keyword.lower() in row[2].lower():
                cidr_list.append(row[0])
    
    with open(output_file, "w", encoding="utf-8") as f:
        for cidr in cidr_list:
            f.write(f"{cidr}\n")
    print(f"Extracted {len(cidr_list)} CIDR ranges to {output_file}")

def main():
    parser = argparse.ArgumentParser(description="Extract CIDR ranges from GeoLite2 ASN CSV based on a keyword.")
    parser.add_argument("--update", action="store_true", help="Download the latest ASN CSV file.")
    parser.add_argument("--keyword", type=str, default="alibaba", help="Keyword to search for in ASN names (default: alibaba).")
    args = parser.parse_args()

    csv_file = "GeoLite2-ASN-Blocks-IPv4.csv"
    output_file = f"{args.keyword}_cidr.txt"

    if args.update or not os.path.exists(csv_file):
        download_latest_asn_csv()
    else:
        print("Using existing ASN CSV file.")

    if os.path.exists(csv_file):
        extract_cidr_by_keyword(csv_file, args.keyword, output_file)
    else:
        print("ASN CSV file not found. Please run with --update to download it.")

if __name__ == "__main__":
    main() 

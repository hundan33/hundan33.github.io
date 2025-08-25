# github_mirror_downloader.py
# GitHub mirror downloader with automatic fallback support

import requests
import json
import os
import time
from typing import List, Dict, Optional, Tuple

# GitHub mirror sources list
GITHUB_MIRRORS = [
    {
        'url': 'https://gh.h233.eu.org/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [@X.I.U/XIU2]'
    },
    {
        'url': 'https://ghproxy.1888866.xyz/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [WJQSERVER-STUDIO/ghproxy]'
    },
    {
        'url': 'https://gh.ddlc.top/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [@mtr-static-official]'
    },
    {
        'url': 'https://gh-proxy.com/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gh-proxy.com]'
    },
    {
        'url': 'https://cors.isteed.cc/github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [@Lufs\'s]'
    },
    {
        'url': 'https://hub.gitmirror.com/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [GitMirror]'
    },
    {
        'url': 'https://ghproxy.cfd/https://github.com',
        'location': 'US',
        'description': '[US Los Angeles] - Provided by [@yionchilau]'
    },
    {
        'url': 'https://github.boki.moe/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [blog.boki.moe]'
    },
    {
        'url': 'https://github.moeyy.xyz/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [moeyy.cn]'
    },
    {
        'url': 'https://gh-proxy.net/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gh-proxy.net]'
    },
    {
        'url': 'https://gh.jasonzeng.dev/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gh.jasonzeng.dev]'
    },
    {
        'url': 'https://gh.monlor.com/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gh.monlor.com]'
    },
    {
        'url': 'https://fastgit.cc/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [fastgit.cc]'
    },
    {
        'url': 'https://github.tbedu.top/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [github.tbedu.top]'
    },
    {
        'url': 'https://firewall.lxstd.org/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [firewall.lxstd.org]'
    },
    {
        'url': 'https://github.ednovas.xyz/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [github.ednovas.xyz]'
    },
    {
        'url': 'https://ghfile.geekertao.top/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [ghfile.geekertao.top]'
    },
    {
        'url': 'https://ghp.keleyaa.com/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [ghp.keleyaa.com]'
    },
    {
        'url': 'https://gh.chjina.com/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gh.chjina.com]'
    },
    {
        'url': 'https://ghpxy.hwinzniej.top/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [ghpxy.hwinzniej.top]'
    },
    {
        'url': 'https://cdn.crashmc.com/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [cdn.crashmc.com]'
    },
    {
        'url': 'https://git.yylx.win/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [git.yylx.win]'
    },
    {
        'url': 'https://gitproxy.mrhjx.cn/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gitproxy.mrhjx.cn]'
    },
    {
        'url': 'https://ghproxy.cxkpro.top/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [ghproxy.cxkpro.top]'
    },
    {
        'url': 'https://gh.xxooo.cf/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gh.xxooo.cf]'
    },
    {
        'url': 'https://github.limoruirui.com/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [github.limoruirui.com]'
    },
    {
        'url': 'https://gh.idayer.com/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gh.idayer.com]'
    },
    {
        'url': 'https://gh.llkk.cc/https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [gh.llkk.cc]'
    },
    {
        'url': 'https://down.npee.cn/?https://github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [npee community]'
    },
    {
        'url': 'https://raw.ihtw.moe/github.com',
        'location': 'US',
        'description': '[US Cloudflare CDN] - Provided by [raw.ihtw.moe]'
    },
    {
        'url': 'https://dgithub.xyz',
        'location': 'US',
        'description': '[US Seattle] - Provided by [dgithub.xyz]'
    },
    {
        'url': 'https://gh.nxnow.top/https://github.com',
        'location': 'US',
        'description': '[US Los Angeles] - Provided by [gh.nxnow.top]'
    },
    {
        'url': 'https://gh.zwy.one/https://github.com',
        'location': 'US',
        'description': '[US Los Angeles] - Provided by [gh.zwy.one]'
    },
    {
        'url': 'https://ghproxy.monkeyray.net/https://github.com',
        'location': 'US',
        'description': '[US Los Angeles] - Provided by [ghproxy.monkeyray.net]'
    },
    {
        'url': 'https://gh.xx9527.cn/https://github.com',
        'location': 'US',
        'description': '[US Los Angeles] - Provided by [gh.xx9527.cn]'
    },
    {
        'url': 'https://ghproxy.net/https://github.com',
        'location': 'UK',
        'description': '[UK London] - Provided by [ghproxy.net]'
    },
    {
        'url': 'https://ghfast.top/https://github.com',
        'location': 'Global',
        'description': '[Japan, Korea, Singapore, US, Germany etc] (CDN varies) - Provided by [ghproxy.link]'
    },
    {
        'url': 'https://wget.la/https://github.com',
        'location': 'Global',
        'description': '[Hong Kong, Taiwan, Japan, US etc] (CDN varies) - Provided by [ucdn.me]'
    }
]

CONFIG_FILE = '.cdn.config'

class GitHubMirrorDownloader:
    def __init__(self, timeout: int = 10):
        self.timeout = timeout
        self.config = self.load_config()
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
    
    def load_config(self) -> Dict:
        """Load configuration from .cdn.config file."""
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"Warning: Failed to load config file: {e}")
        return {
            'last_working_mirror': None, 
            'failed_mirrors': [],
            'preferred_download_mode': None,  # 1=direct, 2=mirror, 3=auto
            'preferred_mirror': None
        }
    
    def save_config(self):
        """Save configuration to .cdn.config file."""
        try:
            with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Warning: Failed to save config file: {e}")
    
    def get_mirror_url(self, github_url: str, mirror_base: str) -> str:
        """Convert GitHub URL to mirror URL."""
        if mirror_base == 'https://dgithub.xyz':
            # Special case for dgithub.xyz
            return github_url.replace('https://github.com', mirror_base)
        elif mirror_base == 'https://raw.ihtw.moe/github.com':
            # Special case for raw.ihtw.moe
            return github_url.replace('https://github.com', mirror_base)
        elif mirror_base == 'https://cors.isteed.cc/github.com':
            # Special case for cors.isteed.cc
            return github_url.replace('https://github.com', mirror_base)
        elif '?' in mirror_base:
            # Special case for URLs with query parameters
            return mirror_base + github_url
        else:
            # Standard case: mirror_base + github_url (remove duplicate https://github.com)
            if mirror_base.endswith('/https://github.com'):
                return mirror_base + github_url.replace('https://github.com', '')
            else:
                return mirror_base + '/' + github_url
    
    def test_mirror_speed(self, mirror: Dict, test_url: str) -> Optional[float]:
        """Test mirror response time."""
        try:
            mirror_url = self.get_mirror_url(test_url, mirror['url'])
            start_time = time.time()
            response = self.session.head(mirror_url, timeout=5)
            end_time = time.time()
            
            if response.status_code in [200, 302, 404]:  # 404 is OK for testing
                return end_time - start_time
            return None
        except Exception:
            return None
    
    def select_best_mirror(self, github_url: str) -> Optional[Dict]:
        """Select the best available mirror based on speed and config."""
        # First try the last working mirror
        if self.config.get('last_working_mirror'):
            for mirror in GITHUB_MIRRORS:
                if mirror['url'] == self.config['last_working_mirror']:
                    if mirror['url'] not in self.config.get('failed_mirrors', []):
                        speed = self.test_mirror_speed(mirror, github_url)
                        if speed is not None:
                            print(f"Using last working mirror: {mirror['url']} ({speed:.2f}s)")
                            return mirror
        
        # Test all available mirrors
        print("Testing available mirrors...")
        working_mirrors = []
        failed_mirrors = self.config.get('failed_mirrors', [])
        
        for mirror in GITHUB_MIRRORS:
            if mirror['url'] in failed_mirrors:
                continue
            
            speed = self.test_mirror_speed(mirror, github_url)
            if speed is not None:
                working_mirrors.append((mirror, speed))
                print(f"✓ {mirror['url']} - {speed:.2f}s")
            else:
                print(f"✗ {mirror['url']} - Failed")
                failed_mirrors.append(mirror['url'])
        
        # Update failed mirrors in config
        self.config['failed_mirrors'] = failed_mirrors
        
        if working_mirrors:
            # Sort by speed and return the fastest
            working_mirrors.sort(key=lambda x: x[1])
            best_mirror = working_mirrors[0][0]
            print(f"Selected fastest mirror: {best_mirror['url']}")
            return best_mirror
        
        return None
    
    def download_with_mirror(self, github_url: str, output_path: str, mirror: Dict) -> bool:
        """Download file using specified mirror."""
        try:
            mirror_url = self.get_mirror_url(github_url, mirror['url'])
            print(f"Downloading from mirror: {mirror_url}")
            
            response = self.session.get(mirror_url, timeout=60, stream=True)
            if response.status_code == 200:
                with open(output_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                
                # Update config with successful mirror
                self.config['last_working_mirror'] = mirror['url']
                if mirror['url'] in self.config.get('failed_mirrors', []):
                    self.config['failed_mirrors'].remove(mirror['url'])
                self.save_config()
                
                print(f"Successfully downloaded using mirror: {mirror['description']}")
                return True
            else:
                print(f"Mirror download failed with status code: {response.status_code}")
                return False
        except Exception as e:
            print(f"Mirror download error: {e}")
            return False
    
    def show_download_options(self) -> str:
        """Show download options and get user choice."""
        print("\n=== GitHub Download Options ===")
        print("1. Direct download (recommended if network is stable)")
        print("2. Use mirror source (recommended for restricted networks)")
        print("3. Auto mode (try direct first, fallback to mirror if failed)")
        print("4. Show available mirrors")
        print("5. Cancel download")
        print("6. Reset preferences")
        
        while True:
            choice = input("\nPlease select an option (1-6, default: 3): ").strip()
            if not choice:
                choice = '3'
            
            if choice in ['1', '2', '3', '4', '5', '6']:
                return choice
            else:
                print("Invalid choice. Please enter 1-6.")
    
    def show_mirror_list(self) -> Optional[Dict]:
        """Show available mirrors and let user choose."""
        print("\n=== Available GitHub Mirrors ===")
        
        # Group mirrors by location for better display
        us_mirrors = [m for m in GITHUB_MIRRORS if m['location'] == 'US']
        uk_mirrors = [m for m in GITHUB_MIRRORS if m['location'] == 'UK']
        global_mirrors = [m for m in GITHUB_MIRRORS if m['location'] == 'Global']
        
        all_mirrors = []
        
        if us_mirrors:
            print("\n--- US Mirrors ---")
            for i, mirror in enumerate(us_mirrors[:10]):  # Show first 10 US mirrors
                idx = len(all_mirrors) + 1
                print(f"{idx:2d}. {mirror['description']}")
                all_mirrors.append(mirror)
        
        if global_mirrors:
            print("\n--- Global Mirrors ---")
            for mirror in global_mirrors:
                idx = len(all_mirrors) + 1
                print(f"{idx:2d}. {mirror['description']}")
                all_mirrors.append(mirror)
        
        if uk_mirrors:
            print("\n--- UK Mirrors ---")
            for mirror in uk_mirrors:
                idx = len(all_mirrors) + 1
                print(f"{idx:2d}. {mirror['description']}")
                all_mirrors.append(mirror)
        
        print(f"\n{len(all_mirrors)+1:2d}. Auto select fastest mirror")
        print(f"{len(all_mirrors)+2:2d}. Back to main menu")
        
        while True:
            try:
                choice = input(f"\nSelect mirror (1-{len(all_mirrors)+2}): ").strip()
                if not choice:
                    continue
                
                choice_num = int(choice)
                if 1 <= choice_num <= len(all_mirrors):
                    return all_mirrors[choice_num - 1]
                elif choice_num == len(all_mirrors) + 1:
                    return None  # Auto select
                elif choice_num == len(all_mirrors) + 2:
                    return 'back'  # Back to main menu
                else:
                    print(f"Invalid choice. Please enter 1-{len(all_mirrors)+2}.")
            except ValueError:
                print("Please enter a valid number.")
    
    def download_file(self, github_url: str, output_path: str) -> bool:
        """Download file with user-selected method."""
        print(f"Attempting to download: {github_url}")
        
        # Check if user has a preferred download mode
        preferred_mode = self.config.get('preferred_download_mode')
        if preferred_mode:
            print(f"Using saved preference: mode {preferred_mode}")
            choice = str(preferred_mode)
        else:
            choice = self.show_download_options()
            # Save user's choice for future downloads
            if choice in ['1', '2', '3']:
                self.config['preferred_download_mode'] = int(choice)
                self.save_config()
                print(f"Preference saved. Use 'reset preferences' to change.")
        
        while True:
            
            if choice == '1':  # Direct download
                print("\nTrying direct download...")
                try:
                    response = self.session.get(github_url, timeout=self.timeout)
                    if response.status_code == 200:
                        with open(output_path, 'wb') as f:
                            f.write(response.content)
                        print("Direct download successful")
                        return True
                    else:
                        print(f"Direct download failed with status code: {response.status_code}")
                        print("Would you like to try a different method?")
                        continue
                except requests.exceptions.Timeout:
                    print(f"Direct download timed out after {self.timeout} seconds")
                    print("Would you like to try a different method?")
                    continue
                except Exception as e:
                    print(f"Direct download error: {e}")
                    print("Would you like to try a different method?")
                    continue
            
            elif choice == '2':  # Use mirror
                # Check if user has a preferred mirror
                preferred_mirror_url = self.config.get('preferred_mirror')
                if preferred_mirror_url:
                    # Find the preferred mirror in the list
                    preferred_mirror = None
                    for mirror in GITHUB_MIRRORS:
                        if mirror['url'] == preferred_mirror_url:
                            preferred_mirror = mirror
                            break
                    
                    if preferred_mirror:
                        print(f"\nUsing saved mirror preference: {preferred_mirror['description']}")
                        return self.download_with_mirror(github_url, output_path, preferred_mirror)
                    else:
                        print("\nSaved mirror preference no longer available, selecting new one...")
                
                selected_mirror = self.show_mirror_list()
                if selected_mirror == 'back':
                    continue
                elif selected_mirror is None:
                    # Auto select fastest mirror
                    print("\nSearching for fastest mirror...")
                    best_mirror = self.select_best_mirror(github_url)
                    if best_mirror:
                        return self.download_with_mirror(github_url, output_path, best_mirror)
                    else:
                        print("No working mirrors found")
                        continue
                else:
                    # Use selected mirror and save preference
                    print(f"\nUsing selected mirror: {selected_mirror['description']}")
                    self.config['preferred_mirror'] = selected_mirror['url']
                    self.save_config()
                    print("Mirror preference saved for future downloads.")
                    return self.download_with_mirror(github_url, output_path, selected_mirror)
            
            elif choice == '3':  # Auto mode
                print("\nTrying direct download first...")
                try:
                    response = self.session.get(github_url, timeout=self.timeout)
                    if response.status_code == 200:
                        with open(output_path, 'wb') as f:
                            f.write(response.content)
                        print("Direct download successful")
                        return True
                    else:
                        print(f"Direct download failed with status code: {response.status_code}")
                except requests.exceptions.Timeout:
                    print(f"Direct download timed out after {self.timeout} seconds")
                except Exception as e:
                    print(f"Direct download error: {e}")
                
                # Fallback to mirror
                print("\nFalling back to mirror download...")
                best_mirror = self.select_best_mirror(github_url)
                if best_mirror:
                    return self.download_with_mirror(github_url, output_path, best_mirror)
                else:
                    print("No working mirrors found")
                    return False
            
            elif choice == '4':  # Show mirrors
                selected_mirror = self.show_mirror_list()
                if selected_mirror == 'back':
                    continue
                elif selected_mirror is None:
                    # Auto select fastest mirror
                    print("\nSearching for fastest mirror...")
                    best_mirror = self.select_best_mirror(github_url)
                    if best_mirror:
                        return self.download_with_mirror(github_url, output_path, best_mirror)
                    else:
                        print("No working mirrors found")
                        return False
                else:
                    # Use selected mirror and save preference
                    print(f"\nUsing selected mirror: {selected_mirror['description']}")
                    self.config['preferred_mirror'] = selected_mirror['url']
                    self.save_config()
                    print("Mirror preference saved for future downloads.")
                    return self.download_with_mirror(github_url, output_path, selected_mirror)
            
            elif choice == '5':  # Cancel
                print("Download cancelled by user")
                return False
            
            elif choice == '6':  # Reset preferences
                self.config['preferred_download_mode'] = None
                self.config['preferred_mirror'] = None
                self.save_config()
                print("Preferences reset. You will be asked to choose again next time.")
                choice = self.show_download_options()
    
    def download_release_asset(self, repo: str, tag: str, filename: str, output_path: str = None) -> bool:
        """Download a specific release asset."""
        if output_path is None:
            output_path = filename
        
        github_url = f"https://github.com/{repo}/releases/download/{tag}/{filename}"
        return self.download_file(github_url, output_path)

def download_with_mirrors(github_url: str, output_path: str, timeout: int = 10) -> bool:
    """Convenience function for downloading with mirror support."""
    downloader = GitHubMirrorDownloader(timeout=timeout)
    return downloader.download_file(github_url, output_path)

def download_release_with_mirrors(repo: str, tag: str, filename: str, output_path: str = None, timeout: int = 10) -> bool:
    """Convenience function for downloading release assets with mirror support."""
    downloader = GitHubMirrorDownloader(timeout=timeout)
    return downloader.download_release_asset(repo, tag, filename, output_path)

if __name__ == "__main__":
    # Example usage
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python github_mirror_downloader.py <github_url> <output_path>")
        print("Example: python github_mirror_downloader.py https://github.com/user/repo/releases/download/v1.0/file.zip file.zip")
        sys.exit(1)
    
    github_url = sys.argv[1]
    output_path = sys.argv[2]
    
    success = download_with_mirrors(github_url, output_path)
    if success:
        print(f"\nDownload completed: {output_path}")
    else:
        print("\nDownload failed")
        sys.exit(1)

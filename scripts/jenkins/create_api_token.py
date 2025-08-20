#!/usr/bin/env python3
"""
Jenkins API Token Creation Script
Version: 1.1.1
Description: Creates API tokens for Jenkins programmatic access
Author: Bogdan Dragos Vasile
"""

import requests
import json
import argparse
import sys
import os
from typing import Optional, Dict, Any

class JenkinsTokenCreator:
    """Handles Jenkins API token creation with proper session management."""
    
    def __init__(self, jenkins_url: str, username: str, password: str):
        self.jenkins_url = jenkins_url.rstrip('/')
        self.username = username
        self.password = password
        self.session = requests.Session()
    
    def get_csrf_crumb(self) -> Optional[Dict[str, str]]:
        """Get CSRF crumb for API requests."""
        try:
            print("🔐 Getting CSRF crumb...")
            response = self.session.get(
                f"{self.jenkins_url}/crumbIssuer/api/json",
                auth=(self.username, self.password),
                timeout=30
            )
            
            if response.status_code != 200:
                print(f"❌ Failed to get crumb: {response.status_code}")
                return None
            
            crumb_data = response.json()
            print(f"✅ Got crumb: {crumb_data['crumb'][:16]}...")
            return crumb_data
            
        except requests.exceptions.RequestException as e:
            print(f"❌ Network error getting crumb: {e}")
            return None
        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON response: {e}")
            return None
    
    def create_api_token(self, token_name: str) -> Optional[str]:
        """Create a new API token for the user."""
        try:
            # Get CSRF crumb first
            crumb_data = self.get_csrf_crumb()
            if not crumb_data:
                return None
            
            print(f"🔑 Creating API token '{token_name}'...")
            
            token_data = {
                "newTokenName": token_name
            }
            
            headers = {
                "Content-Type": "application/json",
                crumb_data['crumbRequestField']: crumb_data['crumb']
            }
            
            response = self.session.post(
                f"{self.jenkins_url}/user/{self.username}/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken",
                auth=(self.username, self.password),
                headers=headers,
                json=token_data,
                timeout=30
            )
            
            if response.status_code == 200:
                try:
                    result = response.json()
                    if 'data' in result and 'tokenValue' in result['data']:
                        token = result['data']['tokenValue']
                        print(f"✅ API Token created successfully!")
                        return token
                    else:
                        print(f"❌ Unexpected response format: {result}")
                        return None
                except json.JSONDecodeError:
                    print(f"❌ Failed to parse JSON response: {response.text}")
                    return None
            else:
                print(f"❌ Failed to create token: {response.status_code}")
                print(f"Response: {response.text}")
                return None
                
        except requests.exceptions.RequestException as e:
            print(f"❌ Network error creating token: {e}")
            return None
    
    def test_token(self, token: str) -> bool:
        """Test if the created token works."""
        try:
            print("🧪 Testing API token...")
            response = requests.get(
                f"{self.jenkins_url}/api/json",
                auth=(self.username, token),
                timeout=30
            )
            
            if response.status_code == 200:
                print("✅ Token test successful!")
                return True
            else:
                print(f"❌ Token test failed: {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"❌ Network error testing token: {e}")
            return False

def main():
    """Main function to handle command line arguments and token creation."""
    parser = argparse.ArgumentParser(
        description="Create Jenkins API token for programmatic access",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -u cursor -p "P8p8c%%4az0" -t "my-api-token"
  %(prog)s -u admin -p "password" -t "jenkins-api-token" -u http://jenkins.example.com
        """
    )
    
    parser.add_argument(
        "-u", "--username",
        required=True,
        help="Jenkins username"
    )
    
    parser.add_argument(
        "-p", "--password",
        required=True,
        help="Jenkins password"
    )
    
    parser.add_argument(
        "-t", "--token-name",
        default="jenkins-api-token",
        help="Name for the API token (default: jenkins-api-token)"
    )
    
    parser.add_argument(
        "-j", "--jenkins-url",
        default="http://localhost:8080",
        help="Jenkins URL (default: http://localhost:8080)"
    )
    
    parser.add_argument(
        "--test",
        action="store_true",
        help="Test the created token"
    )
    
    parser.add_argument(
        "--save-to-file",
        help="Save token to specified file"
    )
    
    args = parser.parse_args()
    
    # Create token creator instance
    creator = JenkinsTokenCreator(args.jenkins_url, args.username, args.password)
    
    # Create the token
    token = creator.create_api_token(args.token_name)
    
    if token:
        print(f"\n🎉 Success! API Token created:")
        print(f"Username: {args.username}")
        print(f"Token: {token}")
        print(f"Jenkins URL: {args.jenkins_url}")
        
        # Test the token if requested
        if args.test:
            creator.test_token(token)
        
        # Save to file if requested
        if args.save_to_file:
            try:
                with open(args.save_to_file, 'w') as f:
                    f.write(f"JENKINS_USERNAME={args.username}\n")
                    f.write(f"JENKINS_API_TOKEN={token}\n")
                    f.write(f"JENKINS_URL={args.jenkins_url}\n")
                print(f"💾 Token saved to: {args.save_to_file}")
            except IOError as e:
                print(f"❌ Failed to save token to file: {e}")
        
        # Show usage examples
        print(f"\n📋 Usage Examples:")
        print(f"curl -u {args.username}:{token} {args.jenkins_url}/api/json")
        print(f"curl -u {args.username}:{token} {args.jenkins_url}/job/k8s-cluster-deploy/api/json")
        
        return 0
    else:
        print("\n❌ Failed to create API token")
        return 1

if __name__ == "__main__":
    sys.exit(main())

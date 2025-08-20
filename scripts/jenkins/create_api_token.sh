#!/bin/bash
# Jenkins API Token Creation Script
# Version: 1.1.1
# Description: Shell wrapper for Jenkins API token creation
# Author: Bogdan Dragos Vasile

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/create_api_token.py"

# Default values
DEFAULT_JENKINS_URL="http://localhost:8080"
DEFAULT_TOKEN_NAME="jenkins-api-token"

# Function to show usage
show_usage() {
    cat << EOF
Jenkins API Token Creation Script v1.1.1

Usage: $0 [OPTIONS]

OPTIONS:
    -u, --username USERNAME     Jenkins username (required)
    -p, --password PASSWORD     Jenkins password (required)
    -t, --token-name NAME       Token name (default: jenkins-api-token)
    -j, --jenkins-url URL       Jenkins URL (default: http://localhost:8080)
    --test                      Test the created token
    --save-to-file FILE         Save token to environment file
    -h, --help                  Show this help message

EXAMPLES:
    $0 -u cursor -p "P8p8c%4az0"
    $0 -u admin -p "password" -t "my-token" -j "http://jenkins.example.com"
    $0 -u cursor -p "P8p8c%4az0" --test --save-to-file .env

REQUIREMENTS:
    - Python 3.6+
    - requests library (pip install requests)

EOF
}

# Function to check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 Checking dependencies...${NC}"
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Python 3 is not installed${NC}"
        exit 1
    fi
    
    # Check if requests library is available
    if ! python3 -c "import requests" &> /dev/null; then
        echo -e "${YELLOW}⚠️  requests library not found. Installing...${NC}"
        pip3 install requests
    fi
    
    echo -e "${GREEN}✅ Dependencies check passed${NC}"
}

# Function to validate arguments
validate_args() {
    if [[ -z "${USERNAME:-}" ]]; then
        echo -e "${RED}❌ Username is required${NC}"
        show_usage
        exit 1
    fi
    
    if [[ -z "${PASSWORD:-}" ]]; then
        echo -e "${RED}❌ Password is required${NC}"
        show_usage
        exit 1
    fi
}

# Function to create token
create_token() {
    echo -e "${BLUE}🚀 Creating Jenkins API token...${NC}"
    
    # Build command
    CMD="python3 \"$PYTHON_SCRIPT\" -u \"$USERNAME\" -p \"$PASSWORD\""
    
    if [[ -n "${TOKEN_NAME:-}" ]]; then
        CMD="$CMD -t \"$TOKEN_NAME\""
    fi
    
    if [[ -n "${JENKINS_URL:-}" ]]; then
        CMD="$CMD -j \"$JENKINS_URL\""
    fi
    
    if [[ "${TEST_TOKEN:-}" == "true" ]]; then
        CMD="$CMD --test"
    fi
    
    if [[ -n "${SAVE_TO_FILE:-}" ]]; then
        CMD="$CMD --save-to-file \"$SAVE_TO_FILE\""
    fi
    
    # Execute the Python script
    eval "$CMD"
}

# Main script
main() {
    echo -e "${BLUE}🔑 Jenkins API Token Creator v1.1.1${NC}"
    echo "=================================="
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--username)
                USERNAME="$2"
                shift 2
                ;;
            -p|--password)
                PASSWORD="$2"
                shift 2
                ;;
            -t|--token-name)
                TOKEN_NAME="$2"
                shift 2
                ;;
            -j|--jenkins-url)
                JENKINS_URL="$2"
                shift 2
                ;;
            --test)
                TEST_TOKEN="true"
                shift
                ;;
            --save-to-file)
                SAVE_TO_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set defaults
    JENKINS_URL="${JENKINS_URL:-$DEFAULT_JENKINS_URL}"
    TOKEN_NAME="${TOKEN_NAME:-$DEFAULT_TOKEN_NAME}"
    
    # Check dependencies
    check_dependencies
    
    # Validate arguments
    validate_args
    
    # Create token
    create_token
}

# Run main function with all arguments
main "$@"

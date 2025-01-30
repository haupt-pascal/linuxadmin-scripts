#!/bin/bash
#
# abuse-ip-check.sh - Check IPs from AbuseIPDB blocklists
# Part of linuxadmin-scripts (https://github.com/haupt-pascal/linuxadmin-scripts)
#
# Description: Clones the AbuseIPDB blocklist repo, processes specified IP lists,
# and checks for active web services on these IPs

# Configuration
REPO_URL="https://github.com/borestad/blocklist-abuseipdb.git"
CLONE_DIR="/tmp/blocklist-abuseipdb-$$"  # Use PID to avoid conflicts
WEBCHECK_SCRIPT="./webcheck.sh"
DEFAULT_LIST="abuseipdb-s100-all.ipv4"
VERBOSE=false
CONNECT_TIMEOUT=1
MAX_TIMEOUT=2

# Function to check if required tools are installed
check_requirements() {
    local missing_tools=()
    
    for tool in git curl awk; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "Error: Required tools are missing: ${missing_tools[*]}"
        echo "Please install them using your package manager."
        exit 1
    fi
}

# Function to clone/update repository
clone_repo() {
    echo "Cloning AbuseIPDB blocklist repository..."
    if ! git clone --depth 1 "$REPO_URL" "$CLONE_DIR"; then
        echo "Error: Failed to clone repository!"
        exit 1
    fi
}

# Function to extract IPs from blocklist file
extract_ips() {
    local input_file="$1"
    local temp_file="$2"
    
    echo "Extracting IPs from $input_file..."
    
    # Extract IPs, removing comments and empty lines
    awk -F'#' '{print $1}' "$input_file" | tr -d ' \t' | grep -v '^$' > "$temp_file"
    
    local ip_count
    ip_count=$(wc -l < "$temp_file")
    echo "Found $ip_count IPs to check"
}

# Function to check a single IP
check_ip() {
    local ip="$1"
    local port="$2"
    
    echo -n "Checking ${ip}:${port}... "
    if curl -s --connect-timeout $CONNECT_TIMEOUT --max-time $MAX_TIMEOUT "http://${ip}:${port}" -o /dev/null; then
        echo "http://${ip}:${port}" >> active.txt
        echo "[+] Active"
        return 0
    else
        echo "[-] Inactive"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -f, --file FILE      Specific blocklist file to check (default: $DEFAULT_LIST)"
    echo "  -p, --port PORT      Port to check (default: 80)"
    echo "  -v, --verbose        Show detailed progress"
    echo
    echo "Examples:"
    echo "  $0"
    echo "  $0 -f abuseipdb-s100-60d.ipv4"
    echo "  $0 -p 8080"
    echo "  $0 -f abuseipdb-s100-all.ipv4 -p 443 -v"
    exit 1
}

# Function to clean up
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$CLONE_DIR"
    [ -f "$TEMP_IP_FILE" ] && rm -f "$TEMP_IP_FILE"
}

# Function to process IP list
process_ip_list() {
    local temp_file="$1"
    local port="$2"
    
    > active.txt  # Clear existing active.txt
    
    while IFS= read -r ip; do
        check_ip "$ip" "$port"
    done < "$temp_file"
}

# Main program
main() {
    local blocklist_file="$DEFAULT_LIST"
    local port="80"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                blocklist_file="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                show_usage
                ;;
        esac
    done
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Check requirements
    check_requirements
    
    # Create temporary file for IPs
    TEMP_IP_FILE=$(mktemp)
    
    # Clone repository
    clone_repo
    
    # Check if specified blocklist exists
    if [ ! -f "$CLONE_DIR/$blocklist_file" ]; then
        echo "Error: Specified blocklist file '$blocklist_file' not found in repository!"
        echo "Available files:"
        ls -1 "$CLONE_DIR"/abuseipdb-*.ipv4
        exit 1
    fi
    
    # Extract IPs
    extract_ips "$CLONE_DIR/$blocklist_file" "$TEMP_IP_FILE"
    
    echo "Starting web service check..."
    process_ip_list "$TEMP_IP_FILE" "$port"
    
    echo "Check completed. Results saved in active.txt"
}

main "$@"
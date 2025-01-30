#!/bin/bash
#
# webcheck.sh - Website availability checker for IPs and CIDR ranges
# Part of linuxadmin-scripts (https://github.com/yourusername/linuxadmin-scripts)
#
# Description: Checks for active websites on specified IPs or CIDR ranges with optional port specification.
# Creates a list of active websites in active.txt
#
# Usage: ./webcheck.sh [options]
# Options:
#   -i, --ip IP/CIDR     Single IP or CIDR range to check
#   -p, --port PORT      Port to check (default: 80)
#   -f, --file FILE      Input file with IPs/CIDR ranges (one per line)

# Function to check a single IP/port combination
check_ip() {
    local ip=$1
    local port=${2:-80}  # Default port 80 if not specified
    
    # 15 second timeout for curl (--max-time includes connection and operation timeout)
    echo -n "Checking ${ip}:${port}... "
    if curl -s --connect-timeout 10 --max-time 15 "http://${ip}:${port}" -o /dev/null; then
        echo "http://${ip}:${port}" >> active.txt
        echo -e "\r[+] Active: http://${ip}:${port}  "
    else
        echo -e "\r[-] Inactive: ${ip}:${port}  "
    fi
}

# Function to expand CIDR range
expand_cidr() {
    local cidr=$1
    local port=$2
    
    # Check if ipcalc is installed
    if ! command -v ipcalc >/dev/null 2>&1; then
        echo "Error: ipcalc is not installed. Please install it using 'apt-get install ipcalc' or 'yum install ipcalc'"
        exit 1
    fi
    
    # Extract network start and end
    local network=$(ipcalc -n "$cidr" | grep Network | awk '{print $2}')
    local broadcast=$(ipcalc -b "$cidr" | grep Broadcast | awk '{print $2}')
    
    # Convert IPs to numbers
    local start_ip=$(echo "$network" | awk -F. '{print ($1*256*256*256)+($2*256*256)+($3*256)+$4}')
    local end_ip=$(echo "$broadcast" | awk -F. '{print ($1*256*256*256)+($2*256*256)+($3*256)+$4}')
    
    # Iterate through all IPs in range
    for ((ip=start_ip; ip<=end_ip; ip++)); do
        local ip_addr=$(printf "%d.%d.%d.%d" $(($ip>>24&255)) $(($ip>>16&255)) $(($ip>>8&255)) $(($ip&255)))
        check_ip "$ip_addr" "$port"
    done
}

# Function to process input file
process_input_file() {
    local file=$1
    local port=$2
    
    if [ ! -f "$file" ]; then
        echo "Error: Input file $file not found!"
        exit 1
    fi
    
    echo "Processing IPs from $file..."
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Strip whitespace
        line=$(echo "$line" | tr -d '[:space:]')
        
        if [[ "$line" =~ "/" ]]; then
            # CIDR notation
            expand_cidr "$line" "$port"
        else
            # Single IP
            check_ip "$line" "$port"
        fi
    done < "$file"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -i, --ip IP/CIDR     Single IP or CIDR range to check"
    echo "  -p, --port PORT      Port to check (default: 80)"
    echo "  -f, --file FILE      Input file with IPs/CIDR ranges (one per line)"
    echo
    echo "Examples:"
    echo "  $0 -i 192.168.1.1"
    echo "  $0 -i 192.168.1.1 -p 8080"
    echo "  $0 -i 192.168.1.0/24"
    echo "  $0 -f input.txt"
    echo "  $0 -f input.txt -p 8080"
    exit 1
}

# Main program
main() {
    local ip=""
    local port="80"
    local input_file=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--ip)
                ip="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -f|--file)
                input_file="$2"
                shift 2
                ;;
            *)
                show_usage
                ;;
        esac
    done
    
    # Clear existing active.txt
    > active.txt
    
    # Check if we have either IP or input file
    if [ -z "$ip" ] && [ -z "$input_file" ]; then
        show_usage
    fi
    
    # Process input file if specified
    if [ -n "$input_file" ]; then
        process_input_file "$input_file" "$port"
    fi
    
    # Process single IP/CIDR if specified
    if [ -n "$ip" ]; then
        if [[ "$ip" =~ "/" ]]; then
            expand_cidr "$ip" "$port"
        else
            check_ip "$ip" "$port"
        fi
    fi
    
    echo -e "\nDone! Active websites have been saved to active.txt"
}

main "$@"

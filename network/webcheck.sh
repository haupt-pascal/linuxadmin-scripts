#!/bin/bash
#
# webcheck.sh - website vibe checker fr fr
# part of linuxadmin-scripts (https://github.com/haupt-pascal/linuxadmin-scripts)
#
# tl;dr: checks if websites are alive on IPs/CIDR ranges
# makes a list of the valid ones in active.txt (pretty basic tbh)
#
# how to use this thing:
#   -i, --ip IP/CIDR     drop an IP or CIDR range here
#   -p, --port PORT      which port to check (defaults to 80 like it's 1999)
#   -f, --file FILE      text file with IPs/CIDRs (one per line, don't be extra)

# vibe check a single IP
check_ip() {
    local ip=$1
    local port=${2:-80}  # defaulting to 80 cuz we're old school like that
    
    # timeout after 15s (ain't nobody got time for that)
    echo -n "checking http://${ip}:${port}... "
    if curl -s --connect-timeout 3 --max-time 8 "http://${ip}:${port}" -o /dev/null; then
        echo "http://${ip}:${port}" >> active.txt
        echo -e "\r[W] website found: http://${ip}:${port} (it passed the vibe check)  "
    else
        echo -e "\r[L] no website: ${ip}:${port} (took the L)  "
    fi
}

# expand CIDR range like it's a YouTube video
expand_cidr() {
    local cidr=$1
    local port=$2
    
    # check if we got ipcalc (essential tool no cap)
    if ! command -v ipcalc >/dev/null 2>&1; then
        echo "bestie, you need ipcalc installed"
        echo "do 'apt-get install ipcalc' or 'yum install ipcalc' depending on your vibe"
        exit 1
    fi
    
    # get the network deets
    local network=$(ipcalc -n "$cidr" | grep Network | awk '{print $2}')
    local broadcast=$(ipcalc -b "$cidr" | grep Broadcast | awk '{print $2}')
    
    # math time (ugh), converting IPs to numbers
    local start_ip=$(echo "$network" | awk -F. '{print ($1*256*256*256)+($2*256*256)+($3*256)+$4}')
    local end_ip=$(echo "$broadcast" | awk -F. '{print ($1*256*256*256)+($2*256*256)+($3*256)+$4}')
    
    # slide into every IP's DMs
    for ((ip=start_ip; ip<=end_ip; ip++)); do
        local ip_addr=$(printf "%d.%d.%d.%d" $(($ip>>24&255)) $(($ip>>16&255)) $(($ip>>8&255)) $(($ip&255)))
        check_ip "$ip_addr" "$port"
    done
}

# read the input file like it's a Twitter feed
process_input_file() {
    local file=$1
    local port=$2
    
    if [ ! -f "$file" ]; then
        echo "file not found bestie, that's kinda sus"
        exit 1
    fi
    
    echo "reading IPs from $file (please be patient, I'm not a Chrome tab)"
    while IFS= read -r line || [ -n "$line" ]; do
        # skip the empty lines and comments (we're not that desperate)
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # remove whitespace (ain't nobody got time for that)
        line=$(echo "$line" | tr -d '[:space:]')
        
        if [[ "$line" =~ "/" ]]; then
            # CIDR notation (fancy network stuff)
            expand_cidr "$line" "$port"
        else
            # just a regular IP (keeping it simple)
            check_ip "$line" "$port"
        fi
    done < "$file"
}

# explain how to use this thing
show_usage() {
    echo "how to use this thing:"
    echo "$0 [options] (it's not rocket science)"
    echo
    echo "options (pick your poison):"
    echo "  -i, --ip IP/CIDR     yeet in an IP or CIDR range"
    echo "  -p, --port PORT      which port to check (defaults to 80)"
    echo "  -f, --file FILE      file with IPs/CIDRs (one per line plz)"
    echo
    echo "examples (because reading is hard):"
    echo "  $0 -i 192.168.1.1"
    echo "  $0 -i 192.168.1.1 -p 8080"
    echo "  $0 -i 192.168.1.0/24"
    echo "  $0 -f input.txt"
    echo "  $0 -f input.txt -p 8080"
    exit 1
}

# main character energy
main() {
    local ip=""
    local port="80"
    local input_file=""
    
    # parse them args like it's a TikTok caption
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
    
    # yeet the old active.txt
    > active.txt
    
    # make sure we got something to work with
    if [ -z "$ip" ] && [ -z "$input_file" ]; then
        echo "bestie, I need either an IP or a file to work with"
        show_usage
    fi
    
    # process that input file if we got one
    if [ -n "$input_file" ]; then
        process_input_file "$input_file" "$port"
    fi
    
    # handle single IP/CIDR (keeping it simple)
    if [ -n "$ip" ]; then
        if [[ "$ip" =~ "/" ]]; then
            expand_cidr "$ip" "$port"
        else
            check_ip "$ip" "$port"
        fi
    fi
    
    echo -e "\nwe done bestie! check active.txt for the ones that passed the vibe check"
}

# let's get this bread
main "$@"
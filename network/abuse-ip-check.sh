#!/bin/bash
#
# abuse-ip-check.sh - fr fr no cap this script checks IPs efficiently
# like seriously, it's based (using only core utils)
#
# config stuff (don't touch unless you know what you're doing bestie)
REPO_URL="https://github.com/borestad/blocklist-abuseipdb.git"
CLONE_DIR="/tmp/blocklist-abuseipdb-$$"
DEFAULT_LIST="abuseipdb-s100-all.ipv4"
CONNECT_TIMEOUT=1
MAX_TIMEOUT=2
MAX_WORKERS=100
TEMP_DIR="/tmp/ipcheck-$$"
MAIN_PID=$$
ACTIVE_IPS_FILE="$PWD/active.txt"

# debug output (respectfully)
debug() {
    [ "$VERBOSE" = true ] && echo "[DEBUG] $*"
}

# cleanup on aisle 5
cleanup() {
    echo
    echo "brb, cleaning up this mess..."
    pkill -P $MAIN_PID
    sleep 1
    pkill -9 -P $MAIN_PID 2>/dev/null
    rm -rf "$CLONE_DIR" "$TEMP_DIR"
    echo "ight we clean now"
    exit 0
}

# check if we got the tools we need
check_requirements() {
    local tools=(git curl awk split pkill)
    for tool in "${tools[@]}"; do
        command -v "$tool" >/dev/null 2>&1 || { echo "bestie, we need $tool installed"; exit 1; }
    done
}

# yoink that repo real quick
clone_repo() {
    echo "yoinking that repo..."
    git clone --depth 1 --single-branch --no-tags "$REPO_URL" "$CLONE_DIR" || { echo "nah fam, clone failed"; exit 1; }
}

# extract them IPs like it's a TikTok trend
extract_ips() {
    local input_file="$1"
    local output_pipe="$2"
    
    echo "extracting IPs from $input_file no cap"
    
    if [ ! -f "$input_file" ]; then
        echo "file not found bestie, that's kinda sus"
        exit 1
    fi
    
    # stream those IPs like it's Spotify
    awk '
    /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {
        print $1
        fflush()
        count++
    }
    END { print "# sheesh... " count " IPs processed" > "/dev/stderr" }
    ' "$input_file" > "$output_pipe" &
}

# check if these IPs are bussin or sus
check_chunk() {
    local chunk_file="$1"
    local port="$2"
    local pid_file="$3"
    local results_lock="$4"
    
    echo $$ > "$pid_file"
    
    while IFS= read -r ip; do
        debug "checking http://${ip}:${port}"
        if curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout $CONNECT_TIMEOUT \
            --max-time $MAX_TIMEOUT \
            "http://${ip}:${port}" 2>/dev/null | grep -q "^[23]"; then
            # no race conditions in this house
            (
                flock -x 200
                echo "http://${ip}:${port}" >> "$ACTIVE_IPS_FILE"
                echo "[+] http://${ip}:${port} is alive and vibing"
            ) 200>"$results_lock"
        fi
    done < "$chunk_file"
    
    rm -f "$pid_file"
}

# multiprocessing go brrrrr
process_ips_multiprocess() {
    local input_pipe="$1"
    local workers="$2"
    local port="$3"
    
    mkdir -p "$TEMP_DIR"/{chunks,pids}
    > "$ACTIVE_IPS_FILE"
    
    # lock file to keep things bussin
    local results_lock="$TEMP_DIR/results.lock"
    touch "$results_lock"
    
    # save all IPs temporarily (like a story that doesn't expire)
    local all_ips_file="$TEMP_DIR/all_ips.txt"
    cat "$input_pipe" > "$all_ips_file"
    
    # math time (ugh)
    local total_ips=$(wc -l < "$all_ips_file")
    local chunk_size=$(( (total_ips + workers - 1) / workers ))
    
    debug "total IPs: $total_ips"
    debug "worker count: $workers"
    debug "IPs per worker: $chunk_size"
    
    # split work like sharing a pizza
    cd "$TEMP_DIR/chunks" || exit 1
    split -l "$chunk_size" "$all_ips_file" "chunk_"
    
    echo "spawning $workers workers (they're not getting paid)"
    
    # let the workers do their thing
    for chunk in chunk_*; do
        local pid_file="$TEMP_DIR/pids/$chunk.pid"
        check_chunk "$TEMP_DIR/chunks/$chunk" "$port" "$pid_file" "$results_lock" &
        debug "worker $chunk is doing their thing (PID: $!)"
    done
    
    # wait for everyone to finish their tasks (like waiting for people to respond in a group chat)
    wait
    
    local found_count=$(wc -l < "$ACTIVE_IPS_FILE")
    echo "found $found_count active IPs (that's pretty bussin)"
}

# the main character
main() {
    local blocklist_file="$DEFAULT_LIST"
    local port="80"
    local workers="$MAX_WORKERS"
    VERBOSE=false
    
    # parse them args like it's a tweet
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file) blocklist_file="$2"; shift 2 ;;
            -p|--port) port="$2"; shift 2 ;;
            -w|--workers) workers="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -h|--help)
                echo "usage: $0 [-f FILE] [-p PORT] [-w WORKERS] [-v]"
                echo "bestie just run it with -w 50 -p 80 trust"
                exit 0
                ;;
            *) echo "idk what $1 is supposed to mean"; exit 1 ;;
        esac
    done
    
    trap cleanup EXIT INT TERM
    check_requirements
    
    clone_repo
    
    local full_blocklist_path="$CLONE_DIR/$blocklist_file"
    if [ ! -f "$full_blocklist_path" ]; then
        echo "can't find that blocklist bestie"
        echo "here's what we got tho:"
        find "$CLONE_DIR" -name "abuseipdb-*.ipv4" -exec basename {} \;
        exit 1
    fi
    
    # make our temp directory and pipe (like a collab)
    mkdir -p "$TEMP_DIR"
    local ip_pipe="$TEMP_DIR/ip_pipe"
    mkfifo "$ip_pipe"
    
    # let's get this bread
    extract_ips "$full_blocklist_path" "$ip_pipe"
    process_ips_multiprocess "$ip_pipe" "$workers" "$port"
    
    rm -f "$ip_pipe"
}

main "$@"
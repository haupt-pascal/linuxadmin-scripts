#!/bin/bash
#
# abuse-ip-check.sh - Hochperformante IP-Prüfung mit Basis-Tools
#
# Konfiguration
REPO_URL="https://github.com/borestad/blocklist-abuseipdb.git"
CLONE_DIR="/tmp/blocklist-abuseipdb-$$"
DEFAULT_LIST="abuseipdb-s100-all.ipv4"
CONNECT_TIMEOUT=1
MAX_TIMEOUT=2
MAX_WORKERS=100
TEMP_DIR="/tmp/ipcheck-$$"
MAIN_PID=$$

# Debug-Funktion
debug() {
    [ "$VERBOSE" = true ] && echo "[DEBUG] $*"
}

# Prozess-Cleanup
cleanup() {
    echo
    echo "Cleanup... Beende alle Prozesse..."
    pkill -P $MAIN_PID
    sleep 1
    pkill -9 -P $MAIN_PID 2>/dev/null
    rm -rf "$CLONE_DIR" "$TEMP_DIR"
    echo "Cleanup abgeschlossen."
    exit 0
}

# Abhängigkeiten prüfen
check_requirements() {
    local tools=(git curl awk split pkill)
    for tool in "${tools[@]}"; do
        command -v "$tool" >/dev/null 2>&1 || { echo "Fehler: $tool ist nicht installiert"; exit 1; }
    done
}

# Repository klonen
clone_repo() {
    echo "Klone Repository..."
    git clone --depth 1 --single-branch --no-tags "$REPO_URL" "$CLONE_DIR" || { echo "Fehler beim Klonen"; exit 1; }
}

# IP-Extraktion
extract_ips() {
    local input_file="$1"
    local temp_file="$2"
    
    echo "Extrahiere IPs aus $input_file..."
    
    if [ ! -f "$input_file" ]; then
        echo "Fehler: Datei $input_file nicht gefunden!"
        exit 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo "Erste 5 Zeilen der Datei:"
        head -n 5 "$input_file"
    fi
    
    # Extrahiere nur die IP-Adressen
    awk '
    /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {
        print $1  # Nur die IP-Adresse (erstes Feld)
        count++
    }
    END { print "# " count " IPs processed" > "/dev/stderr" }
    ' "$input_file" > "$temp_file"
    
    local ip_count=$(wc -l < "$temp_file")
    echo "$ip_count IPs gefunden"
    
    if [ "$ip_count" -eq 0 ]; then
        echo "Fehler: Keine gültigen IPs in der Datei gefunden!"
        exit 1
    fi
}

# IP-Prüfung für einen Chunk
check_chunk() {
    local chunk_file="$1"
    local port="$2"
    local pid_file="$3"
    local result_file="$4"
    
    echo $$ > "$pid_file"
    
    while IFS= read -r ip; do
        debug "Prüfe IP: $ip:$port"
        if curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout $CONNECT_TIMEOUT \
            --max-time $MAX_TIMEOUT \
            "http://${ip}:${port}" 2>/dev/null | grep -q "^[23]"; then
            echo "$ip" >> "$result_file"
            echo "[+] $ip:$port aktiv"
        fi
    done < "$chunk_file"
    
    rm -f "$pid_file"
}

# Hauptfunktion für Multiprocessing
process_ips_multiprocess() {
    local temp_file="$1"
    local workers="$2"
    local port="$3"
    
    mkdir -p "$TEMP_DIR"/{chunks,pids,results}
    > active.txt
    
    local total_ips=$(wc -l < "$temp_file")
    local chunk_size=$(( (total_ips + workers - 1) / workers ))
    
    debug "Gesamt IPs: $total_ips"
    debug "Chunk-Größe: $chunk_size"
    debug "Worker: $workers"
    
    cd "$TEMP_DIR/chunks" || exit 1
    split -l "$chunk_size" "$temp_file" "chunk_"
    
    echo "Starte Überprüfung mit $workers Workern..."
    
    for chunk in chunk_*; do
        [ -f "$chunk" ] || continue
        local pid_file="$TEMP_DIR/pids/$chunk.pid"
        local result_file="$TEMP_DIR/results/$chunk.txt"
        
        while [ "$(find "$TEMP_DIR/pids" -type f | wc -l)" -ge "$workers" ]; do
            for p in "$TEMP_DIR"/pids/*.pid; do
                [ -f "$p" ] || continue
                if ! kill -0 "$(cat "$p")" 2>/dev/null; then
                    rm "$p"
                fi
            done
            sleep 0.1
        done
        
        check_chunk "$TEMP_DIR/chunks/$chunk" "$port" "$pid_file" "$result_file" &
        debug "Worker für $chunk gestartet (PID: $!)"
    done
    
    wait
    
    # Alle Ergebnisse zusammenführen
    if [ -d "$TEMP_DIR/results" ]; then
        cat "$TEMP_DIR"/results/*.txt 2>/dev/null | sort -u > active.txt
        local found_count=$(wc -l < active.txt)
        echo "Gefundene aktive IPs: $found_count"
    else
        echo "Keine aktiven IPs gefunden."
        touch active.txt
    fi
}

# Hauptprogramm
main() {
    local blocklist_file="$DEFAULT_LIST"
    local port="80"
    local workers="$MAX_WORKERS"
    VERBOSE=false
    
    # Parse Kommandozeilenargumente
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file) blocklist_file="$2"; shift 2 ;;
            -p|--port) port="$2"; shift 2 ;;
            -w|--workers) workers="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -h|--help)
                echo "Verwendung: $0 [-f DATEI] [-p PORT] [-w WORKER] [-v]"
                exit 0
                ;;
            *) echo "Unbekannte Option: $1"; exit 1 ;;
        esac
    done
    
    trap cleanup EXIT INT TERM
    check_requirements
    
    local temp_ip_file=$(mktemp)
    clone_repo
    
    local full_blocklist_path="$CLONE_DIR/$blocklist_file"
    if [ ! -f "$full_blocklist_path" ]; then
        echo "Fehler: Blockliste '$blocklist_file' nicht gefunden!"
        echo "Verfügbare Listen:"
        find "$CLONE_DIR" -name "abuseipdb-*.ipv4" -exec basename {} \;
        exit 1
    fi
    
    extract_ips "$full_blocklist_path" "$temp_ip_file"
    process_ips_multiprocess "$temp_ip_file" "$workers" "$port"
}

main "$@"
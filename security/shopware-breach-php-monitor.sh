#!/bin/bash
#
# shopware-breach-php-monitor.sh - hunting for sus PHP files fr fr
# part of linuxadmin-scripts (https://github.com/haupt-pascal/linuxadmin-scripts)
#
# tl;dr: recursively looks for sussy PHP files and tells you what's up
#
# how to use: ./shopware-breach-php-monitor.sh [scan-path]

# where we looking bestie
SCAN_PATH="${1:-.}"

# slide into these DMs when we find something sus
EMAIL_TO="support@profihost.com"

# list of files that are mad sus no cap
SUSPICIOUS_FILES=(
    "cmd.php"        # kinda sus
    "client.php"     # major red flag
    "shell.php"      # bestie why
    "backdoor.php"   # bruh moment
    "c99.php"        # that's gonna be a yikes from me
    "r57.php"        # straight up not having a good time
    "webshell.php"   # this ain't it chief
)

# also check file content for sussy stuff
SUSPICIOUS_PATTERNS=(
    'base64_decode.*eval'
    'eval.*base64_decode'
    'shell_exec'
    'passthru'
    'system\s*\('
    'exec\s*\('
    'eval\s*\('
)

# where we spill the tea
LOG_FILE="/var/log/php-malware-monitor.log"
TEMP_FILE="/tmp/php-malware-findings-$$.txt"

# spill the tea into our log
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# check if a file is sus based on its content
check_file_content() {
    local file="$1"
    local found_something=0
    local findings=""

    # Skip if file is too big (>10MB) to avoid memory issues
    if [ $(stat -f%z "$file" 2>/dev/null || stat -c%s "$file") -gt 10485760 ]; then
        findings="File too large to scan: $file"
        return 1
    fi

    # Check each suspicious pattern
    for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
        if grep -l "$pattern" "$file" >/dev/null 2>&1; then
            findings+="   - Found pattern: $pattern\n"
            found_something=1
        fi
    done

    if [ $found_something -eq 1 ]; then
        echo -e "$file:\n$findings" >> "$TEMP_FILE"
        log_message "🚨 Found sus content in: $file"
        return 0
    fi
    return 1
}

# slide into someone's DMs (email them)
send_email() {
    local subject="$1"
    local body="$2"
    local from_email="shopware-monitor@$(hostname -f)"
    
    log_message "📧 Attempting to send email notification..."
    
    if command -v sendmail >/dev/null 2>&1; then
        {
            echo "From: Shopware Security Monitor (aka the vibe checker) <${from_email}>"
            echo "To: ${EMAIL_TO}"
            echo "Subject: ${subject}"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo
            echo -e "$body"
        } | sendmail -t -i
        
        if [ $? -eq 0 ]; then
            log_message "📨 Email sent successfully to ${EMAIL_TO}"
        else
            log_message "❌ Email failed to send via sendmail"
        fi
    else
        log_message "❌ sendmail not found - install postfix or another MTA"
        echo "Would have sent:"
        echo "Subject: $subject"
        echo -e "Body:\n$body"
    fi
}

# main character energy - scanning for sus files
scan_for_suspicious_files() {
    local base_path="$1"
    local found_count=0
    
    log_message "🔍 Starting scan in: $(readlink -f "$base_path")"
    
    # Clean up any old findings
    > "$TEMP_FILE"
    
    # First check for suspicious filenames
    for file in "${SUSPICIOUS_FILES[@]}"; do
        while IFS= read -r -d '' found_file; do
            echo "Suspicious filename found: $found_file" >> "$TEMP_FILE"
            log_message "⚠️ Found sus file: $found_file"
            ((found_count++))
        done < <(find "$base_path" -type f -name "$file" -print0 2>/dev/null)
    done
    
    # Then scan PHP files for suspicious content
    while IFS= read -r -d '' php_file; do
        # log_message "🔎 Scanning: $php_file"
        check_file_content "$php_file"
        if [ $? -eq 0 ]; then
            ((found_count++))
        fi
    done < <(find "$base_path" -type f -name "*.php" -print0 2>/dev/null)
    
    # If we found anything sus, send the notification
    if [ $found_count -gt 0 ]; then
        local subject="[NO CAP] found $found_count sus PHP files on $(hostname)"
        local body="yo bestie, found some super sus PHP files:\n\n"
        body+="$(cat "$TEMP_FILE")\n\n"
        body+="where we looked: $(readlink -f "$base_path")\n"
        body+="when we caught them: $(date '+%Y-%m-%d %H:%M:%S')\n"
        body+="on this server: $(hostname)\n"
        body+="\ncheck these files rn fr fr 😳"
        
        send_email "$subject" "$body"
        log_message "🚨 Found $found_count suspicious files/patterns"
        echo "Full details in $LOG_FILE"
    else
        log_message "✅ No suspicious files or patterns found"
    fi
    
    # Return the count for the main function
    return $found_count
}

# make sure we got a place to spill the tea
mkdir -p "$(dirname "$LOG_FILE")"

# let's get this bread
scan_for_suspicious_files "$SCAN_PATH"
scan_result=$?

# clean up after ourselves like mom taught us
rm -f "$TEMP_FILE"

# return appropriate exit code
exit $scan_result
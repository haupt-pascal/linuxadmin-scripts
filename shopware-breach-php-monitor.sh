#!/bin/bash
#
# shopware-breach-php-monitor.sh - Monitor for suspicious PHP files
# Part of linuxadmin-scripts (https://github.com/haupt-pascal/linuxadmin-scripts)
#
# Description: Searches for potentially malicious PHP files and sends email notifications
# when suspicious files are found.
#
# Usage: ./shopware-breach-php-monitor.sh [scan-path]

# Configuration
SCAN_PATH="${1:-/var/www}"
# EMAIL NEEDS TO BE CHANGES
EMAIL_TO="admin@yourdomain.com"
SUSPICIOUS_FILES=(
    "cmd.php"
    "client.php"
    "shell.php"
    "backdoor.php"
    "c99.php"
    "r57.php"
    "webshell.php"
)

LOG_FILE="/var/log/php-malware-monitor.log"
TEMP_FILE="/tmp/php-malware-findings.txt"

# Function to send email using sendmail
send_email() {
    local subject="$1"
    local body="$2"
    local from_email="shopware-monitor@$(hostname -f)"
    
    if command -v sendmail >/dev/null 2>&1; then
        {
            echo "From: Shopware Security Monitor <${from_email}>"
            echo "To: ${EMAIL_TO}"
            echo "Subject: ${subject}"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo
            echo -e "$body"
        } | sendmail -t -i
        
        if [ $? -eq 0 ]; then
            log_message "Email sent successfully to ${EMAIL_TO}"
        else
            log_message "Error sending email via sendmail"
            echo "Error: Failed to send email via sendmail"
        fi
    else
        error_msg="Error: 'sendmail' not found. Please install postfix or other MTA."
        log_message "$error_msg"
        echo "$error_msg"
        echo "Email would have been sent with:"
        echo "Subject: $subject"
        echo -e "Body:\n$body"
    fi
}

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Main scanning function
scan_for_suspicious_files() {
    local pattern=""
    
    # Build pattern for find command
    for file in "${SUSPICIOUS_FILES[@]}"; do
        if [ -z "$pattern" ]; then
            pattern="-name $file"
        else
            pattern="$pattern -o -name $file"
        fi
    done
    
    # Clear temporary file
    > "$TEMP_FILE"
    
    # Execute find command and store results
    eval "find \"$SCAN_PATH\" -type f \( $pattern \) -exec ls -l {} \;" > "$TEMP_FILE"
    
    # Check if any suspicious files were found
    if [ -s "$TEMP_FILE" ]; then
        local subject="[ALERT] Suspicious PHP files detected on $(hostname)"
        local body="The following suspicious PHP files were detected:\n\n"
        body+="$(cat "$TEMP_FILE")\n\n"
        body+="Scan path: $SCAN_PATH\n"
        body+="Timestamp: $(date '+%Y-%m-%d %H:%M:%S')\n"
        body+="Hostname: $(hostname)\n"
        body+="\nPlease investigate these files immediately."
        
        send_email "$subject" "$body"
        log_message "Suspicious files found and email sent"
        echo "Suspicious files found! Check $LOG_FILE for details."
    else
        log_message "No suspicious files found"
        echo "No suspicious files found."
    fi
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Main execution
log_message "Starting scan in $SCAN_PATH"
scan_for_suspicious_files
log_message "Scan completed"

# Cleanup
rm -f "$TEMP_FILE"


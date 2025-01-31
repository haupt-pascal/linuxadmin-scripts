#!/bin/bash
#
# shopware-breach-php-monitor.sh - hunting for sus PHP files fr fr
# part of linuxadmin-scripts (https://github.com/haupt-pascal/linuxadmin-scripts)
#
# tl;dr: looks for sussy PHP files and slides into your DMs when it finds something sketch
#
# how to use: ./shopware-breach-php-monitor.sh [scan-path]

# the tea ☕
SCAN_PATH="${1:-/var/www}"
# slide into these DMs when we find something sus
EMAIL_TO="admin@yourdomain.com"

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

# where we spill the tea
LOG_FILE="/var/log/php-malware-monitor.log"
TEMP_FILE="/tmp/php-malware-findings.txt"

# slide into someone's DMs (email them)
send_email() {
    local subject="$1"
    local body="$2"
    local from_email="shopware-monitor@$(hostname -f)"
    
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
            log_message "slid into ${EMAIL_TO}'s DMs successfully"
        else
            log_message "couldn't slide into the DMs, sendmail took an L"
            echo "bruh moment: email failed to send via sendmail"
        fi
    else
        error_msg="bestie, we need 'sendmail' installed... drop that postfix or another MTA real quick"
        log_message "$error_msg"
        echo "$error_msg"
        echo "would've sent this tea:"
        echo "Subject: $subject"
        echo -e "Body:\n$body"
    fi
}

# spill the tea into our log
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# main character energy - scanning for sus files
scan_for_suspicious_files() {
    local pattern=""
    
    # build that pattern like we're making a TikTok dance
    for file in "${SUSPICIOUS_FILES[@]}"; do
        if [ -z "$pattern" ]; then
            pattern="-name $file"
        else
            pattern="$pattern -o -name $file"
        fi
    done
    
    # clean up old tea
    > "$TEMP_FILE"
    
    # time to find some sussy files
    eval "find \"$SCAN_PATH\" -type f \( $pattern \) -exec ls -l {} \;" > "$TEMP_FILE"
    
    # check if we caught anyone acting sus
    if [ -s "$TEMP_FILE" ]; then
        local subject="[NO CAP] caught some sus PHP files on $(hostname)"
        local body="bestie, we found some super sus PHP files:\n\n"
        body+="$(cat "$TEMP_FILE")\n\n"
        body+="where we looked: $SCAN_PATH\n"
        body+="when we caught them: $(date '+%Y-%m-%d %H:%M:%S')\n"
        body+="on this server: $(hostname)\n"
        body+="\nplease check these files rn fr fr, this ain't a drill 😳"
        
        send_email "$subject" "$body"
        log_message "caught some sussy files and spilled the tea"
        echo "found some sus files! peep $LOG_FILE for the tea"
    else
        log_message "everything passed the vibe check"
        echo "we chillin, no sus files found"
    fi
}

# make sure we got a place to spill the tea
mkdir -p "$(dirname "$LOG_FILE")"

# let's get this bread
log_message "starting the vibe check in $SCAN_PATH"
scan_for_suspicious_files
log_message "vibe check complete"

# clean up after ourselves like mom taught us
rm -f "$TEMP_FILE"
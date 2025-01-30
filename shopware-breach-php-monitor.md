# shopware-breach-php-monitor.sh

A bash script specifically designed to monitor Shopware installations for suspicious PHP files that might indicate a security breach. When suspicious files are detected, the script sends email notifications to specified administrators.

## Features

- Scans Shopware directories for known malicious PHP files
- Configurable list of suspicious file patterns commonly found in Shopware breaches
- Email notifications when suspicious files are found
- Detailed logging of all activities
- Can be run manually or via cron job

## Requirements

- bash
- find
- postfix or other MTA (for email notifications)

## Installation

1. Install required packages:
   ```bash
   # For Debian/Ubuntu
   apt-get install postfix

   # For RHEL/CentOS
   yum install postfix
   ```

2. Configure Postfix:
   - During installation, choose "Internet Site" if you want to send emails directly
   - Or choose "Satellite System" if you want to relay through another SMTP server
   - Configure the relay host in /etc/postfix/main.cf if needed

2. Make the script executable:
   ```bash
   chmod +x shopware-breach-php-monitor.sh
   ```

3. Configure the script:
   - Set EMAIL_TO variable to your email address
   - Adjust SUSPICIOUS_FILES array for additional patterns
   - Configure scan path to your Shopware installation directory

## Usage

Manual execution:
```bash
./shopware-breach-php-monitor.sh [shopware-path]
```

### Cron Job Setup

To run the script every hour, add this line to your crontab:
```bash
0 * * * * /path/to/shopware-breach-php-monitor.sh /path/to/shopware
```

To edit your crontab:
```bash
crontab -e
```

## Configuration

The script can be configured by editing the following variables at the top of the file:

- `SCAN_PATH`: Default Shopware installation directory to scan
- `EMAIL_TO`: Email address for notifications
- `SUSPICIOUS_FILES`: Array of suspicious file names to search for
- `LOG_FILE`: Location of the log file

## Output

- Email notifications when suspicious files are found
- Log file at /var/log/php-malware-monitor.log
- Console output for manual execution

## Security Notes

- The script should be run as a user with appropriate permissions to access the Shopware directory
- Regular monitoring of the log file is recommended
- Consider adding additional file patterns based on known Shopware security incidents
- Regular updates to the suspicious file patterns are recommended
- This script is part of a security monitoring strategy and should not be the only measure in place

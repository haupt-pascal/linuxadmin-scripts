# abuse-ip-check.sh

A bash script that checks IPs from AbuseIPDB blocklists for active web services. It automatically clones the blocklist repository, processes the specified list file, and checks each IP for active web services.

## Features

- Automatically clones/updates AbuseIPDB blocklist repository
- Processes various blocklist files (all-time, 60 days, etc.)
- Supports custom port specification
- Uses parallel processing for faster checking
- Automatic cleanup after execution
- Integrates with webcheck.sh for IP checking

## Requirements

- bash
- git
- curl
- awk
- webcheck.sh (must be in the same directory)

## Installation

1. Ensure you have the required tools installed:
   ```bash
   # For Debian/Ubuntu
   apt-get install git curl gawk

   # For RHEL/CentOS
   yum install git curl gawk
   ```

2. Make the script executable:
   ```bash
   chmod +x abuse-ip-check.sh
   ```

## Usage

Basic usage:
```bash
./abuse-ip-check.sh
```

With options:
```bash
./abuse-ip-check.sh [options]
```

### Options

- `-f, --file FILE` : Specific blocklist file to check (default: abuseipdb-s100-all.ipv4)
- `-p, --port PORT` : Port to check (default: 80)
- `-v, --verbose` : Show detailed progress

### Examples

Check all IPs from default list:
```bash
./abuse-ip-check.sh
```

Check specific blocklist file:
```bash
./abuse-ip-check.sh -f abuseipdb-s100-60d.ipv4
```

Check specific port:
```bash
./abuse-ip-check.sh -p 8080
```

Check with verbose output:
```bash
./abuse-ip-check.sh -f abuseipdb-s100-all.ipv4 -p 443 -v
```

## Output

The script creates an `active.txt` file containing URLs of all active web services found in the format:
```
http://IP:PORT
```

## Notes

- The script automatically cleans up temporary files after execution
- Repository is cloned to a temporary directory
- Requires webcheck.sh to be present in the same directory
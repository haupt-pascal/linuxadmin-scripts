# webcheck.sh

A bash script to check for active websites on specified IP addresses or CIDR ranges. The script can process single IPs, CIDR ranges, or a list of IPs from an input file. Active websites are saved to a file for easy access.

## Features

- Check single IP addresses
- Check entire networks using CIDR notation
- Process lists of IPs from input file
- Custom port specification
- Saves active websites to a file
- Progress display in console
- Timeout handling (15 seconds max per check)

## Requirements

- bash
- curl
- ipcalc

## Installation

1. Ensure you have the required tools installed:
   ```bash
   # For Debian/Ubuntu
   apt-get install curl ipcalc

   # For RHEL/CentOS
   yum install curl ipcalc
   ```

2. Make the script executable:
   ```bash
   chmod +x webcheck.sh
   ```

## Usage

```bash
./webcheck.sh [options]
```

### Options
- `-i, --ip IP/CIDR` : Single IP or CIDR range to check
- `-p, --port PORT` : Port to check (default: 80)
- `-f, --file FILE` : Input file with IPs/CIDR ranges (one per line)

### Examples

Check a single IP (default port 80):
```bash
./webcheck.sh -i 192.168.1.1
```

Check a single IP with specific port:
```bash
./webcheck.sh -i 192.168.1.1 -p 8080
```

Check an entire network:
```bash
./webcheck.sh -i 192.168.1.0/24
```

Process IPs from input file:
```bash
./webcheck.sh -f input.txt
```

Process IPs from input file with specific port:
```bash
./webcheck.sh -f input.txt -p 8080
```

### Input File Format

The input file should contain one IP or CIDR range per line. Empty lines and comments (starting with #) are ignored.

Example input.txt:
```
# Production servers
192.168.1.100
192.168.1.101

# Development network
10.0.0.0/24

# Testing servers
172.16.1.50
172.16.1.51
```

## Output

The script creates a file named `active.txt` containing URLs of all active websites found. Each URL is prefixed with `http://` for easy access.

Example active.txt:
```
http://192.168.1.100:80
http://192.168.1.101:80
http://10.0.0.15:80
```

## Notes

- The script uses a connection timeout of 10 seconds and a maximum total timeout of 15 seconds per check
- Progress is displayed in the console during execution
- The active.txt file is overwritten on each run
- Comments in the input file must start with # at the beginning of the line

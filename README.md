# Disk Space Monitor

This is a script to monitor disk space usage and send email alerts if usage exceeds a specified threshold.

## Installation

You can download and install the script using `wget` or `curl`.

### Using wget

```bash
wget https://raw.githubusercontent.com/yourusername/disk-space-monitor/main/disk_space_monitor.sh -O /usr/local/bin/disk_space_monitor.sh
chmod +x /usr/local/bin/disk_space_monitor.sh
```

### Using curl

```bash
curl -o /usr/local/bin/disk_space_monitor.sh https://raw.githubusercontent.com/yourusername/disk-space-monitor/main/disk_space_monitor.sh
chmod +x /usr/local/bin/disk_space_monitor.sh
```

## Usage

```bash
disk_space_monitor.sh [OPTIONS]
```

### Options

- `-a, --add EMAIL`           Add a new email to the notification list.
- `-r, --remove EMAIL`        Remove an email from the notification list.
- `-l, --list`                List all registered email addresses.
- `-c, --check`               Check the disk usage and send alerts if necessary.
- `-t, --threshold NUMBER`    Set a custom disk usage threshold.
- `-s, --setup-postfix`       Automate the Postfix setup process.
- `-T, --test-email EMAIL`    Send a test email to verify configuration.
- `-h, --help`                Display this help message.

## Example

```bash
disk_space_monitor.sh --add your_email@gmail.com
disk_space_monitor.sh --threshold 10
disk_space_monitor.sh --check
```

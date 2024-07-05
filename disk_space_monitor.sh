#!/bin/bash

# Constants
CONFIG_FILE="./config.json"
LOG_FILE="./disk_space_monitor.log"
SUBJECT="🚨 Urgent: Disk Space Alert - Immediate Action Required!"
EMAIL_BODY="<h1 style='color: red;'>🚨 Warning: Critical Disk Space Usage</h1> \
            <p>The server's disk space is currently <strong>%USAGE%</strong> full. Immediate action is required to prevent potential issues.</p> \
            <p style='color: blue;'>Please take the necessary steps to free up space as soon as possible.</p> \
            <p>Thank you for your prompt attention to this matter.</p>"

# Color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize configuration
if [ ! -f "$CONFIG_FILE" ]; then
  echo '{"threshold": 80, "emails": []}' > "$CONFIG_FILE"
fi

# Get threshold and emails from JSON
THRESHOLD=$(jq '.threshold' "$CONFIG_FILE")
EMAILS=$(jq -r '.emails[]' "$CONFIG_FILE")

# Get hostname
HOSTNAME=$(hostname)

# Function to log messages
log_message() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to send email
send_email() {
  local email=$1
  local body=$2
  local subject=$3
  log_message "Preparing to send email to $email with subject: $subject"
  echo -e "Subject: $subject\nMIME-Version: 1.0\nContent-Type: text/html\nContent-Disposition: inline\n\n$body" | sendmail "$email"
  if [ $? -eq 0 ]; then
    log_message "Email successfully sent to $email"
    echo -e "${GREEN}Email successfully sent to $email${NC}"
  else
    log_message "Failed to send email to $email"
    echo -e "${RED}Failed to send email to $email${NC}"
  fi
}

# Function to check disk usage and send alerts
check_disk_usage() {
  local usage=$(df / | grep / | awk '{print $5}' | sed 's/%//g')
  log_message "Current disk usage: $usage%"
  if [ "$usage" -ge "$THRESHOLD" ]; then
    local body=${EMAIL_BODY//"%USAGE%"/"$usage%"}
    local subject="$SUBJECT - Hostname: $HOSTNAME"
    for email in $EMAILS; do
      if [ -n "$email" ]; then
        send_email "$email" "$body" "$subject"
        log_message "Alert sent to $email: Disk usage is $usage%"
      fi
    done
  else
    log_message "Disk usage is at $usage%, no alerts sent."
    echo -e "${BLUE}Disk usage is at $usage%, no alerts sent.${NC}"
  fi
}

# Function to add a new email
add_email() {
  local new_email=$1
  if ! jq -e ".emails[] | select(. == \"$new_email\")" "$CONFIG_FILE" > /dev/null; then
    jq ".emails += [\"$new_email\"]" "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
    log_message "Email added: $new_email"
    echo -e "${GREEN}Email added: $new_email${NC}"
  else
    echo -e "${YELLOW}Email already exists: $new_email${NC}"
  fi
}

# Function to remove an email
remove_email() {
  local remove_email=$1
  if jq -e ".emails[] | select(. == \"$remove_email\")" "$CONFIG_FILE" > /dev/null; then
    jq "del(.emails[] | select(. == \"$remove_email\"))" "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
    log_message "Email removed: $remove_email"
    echo -e "${GREEN}Email removed: $remove_email${NC}"
  else
    echo -e "${YELLOW}Email not found: $remove_email${NC}"
  fi
}

# Function to list all emails
list_emails() {
  if [ $(jq '.emails | length' "$CONFIG_FILE") -gt 0 ]; then
    echo -e "${BLUE}Registered emails:${NC}"
    jq -r '.emails[]' "$CONFIG_FILE"
  else
    echo -e "${YELLOW}No emails registered.${NC}"
  fi
}

# Function to display help
show_help() {
  echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
  echo -e "${GREEN}Options:${NC}"
  echo "  -a, --add EMAIL           Add a new email to the notification list."
  echo "  -r, --remove EMAIL        Remove an email from the notification list."
  echo "  -l, --list                List all registered email addresses."
  echo "  -c, --check               Check the disk usage and send alerts if necessary."
  echo "  -t, --threshold NUMBER    Set a custom disk usage threshold."
  echo "  -s, --setup-postfix       Automate the Postfix setup process."
  echo "  -T, --test-email EMAIL    Send a test email to verify configuration."
  echo "  -h, --help                Display this help message."
}

# Function to check and install required packages
install_packages() {
  REQUIRED_PKG=("postfix" "mailutils" "libsasl2-2" "ca-certificates" "libsasl2-modules" "jq")
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' "${REQUIRED_PKG[@]}" | grep "install ok installed" | wc -l)
  if [ "$PKG_OK" -ne ${#REQUIRED_PKG[@]} ]; then
    echo -e "${YELLOW}Some required packages are not installed. Installing them now...${NC}"
    sudo apt-get update
    sudo apt-get install -y "${REQUIRED_PKG[@]}"
  else
    echo -e "${GREEN}All required packages are already installed.${NC}"
  fi
}

# Function to setup Postfix
setup_postfix() {
  install_packages

  echo -e "${BLUE}Setting up Postfix for Gmail relay...${NC}"
  read -p "Enter your Gmail address: " gmail_email
  read -sp "Enter your Gmail app-specific password: " gmail_password
  echo

  sudo tee /etc/postfix/main.cf > /dev/null <<EOF
smtpd_banner = \$myhostname ESMTP \$mail_name (Ubuntu)
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_tls_security_level=may
smtp_tls_CApath=/etc/ssl/certs
smtp_tls_security_level=may
smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_scache
smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
myhostname = $HOSTNAME
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = $HOSTNAME, localhost.$HOSTNAME, localhost
relayhost = [smtp.gmail.com]:587
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_sasl_tls_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOF

  sudo tee /etc/postfix/sasl_passwd > /dev/null <<EOF
[smtp.gmail.com]:587 $gmail_email:$gmail_password
EOF

  sudo chmod 600 /etc/postfix/sasl_passwd
  sudo postmap /etc/postfix/sasl_passwd
  sudo systemctl reload postfix

  log_message "Postfix setup completed with Gmail relay for $gmail_email"
  echo -e "${GREEN}Postfix setup completed.${NC}"
}

# Function to send a test email
send_test_email() {
  local test_email=$1
  log_message "Sending test email to $test_email"
  echo "This is a test email from the disk space monitor script." | mail -s "Test Email" "$test_email"
  log_message "Test email sent to $test_email"
  echo -e "${GREEN}Test email sent to $test_email.${NC}"
}

# Parse flags
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -a|--add)
      add_email "$2"
      shift # past argument
      shift # past value
      ;;
    -r|--remove)
      remove_email "$2"
      shift # past argument
      shift # past value
      ;;
    -l|--list)
      list_emails
      shift # past argument
      ;;
    -c|--check)
      check_disk_usage
      shift # past argument
      ;;
    -t|--threshold)
      if [ -n "$2" ]; then
        THRESHOLD="$2"
        jq ".threshold = $THRESHOLD" "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
        log_message "Threshold set to $THRESHOLD%"
        echo -e "${GREEN}Threshold set to $THRESHOLD%${NC}"
        shift # past argument
        shift # past value
      else
        read -p "Enter the disk usage threshold (default is $THRESHOLD): " THRESHOLD
        THRESHOLD=${THRESHOLD:-$DEFAULT_THRESHOLD}
        jq ".threshold = $THRESHOLD" "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
        log_message "Threshold set to $THRESHOLD%"
        echo -e "${GREEN}Threshold set to $THRESHOLD%${NC}"
        shift # past argument
      fi
      ;;
    -s|--setup-postfix)
      setup_postfix
      shift # past argument
      ;;
    -T|--test-email)
      send_test_email "$2"
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      show_help
      shift # past argument
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo -e "${RED}Invalid option: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

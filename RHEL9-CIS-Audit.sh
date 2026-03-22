#!/bin/bash

# RHEL9-CIS-Audit.sh - CIS RHEL 9 Level 1 Audit Script
# This script checks compliance with CIS RHEL 9 Level 1 benchmarks
# Version: 1.0.0

# Color codes for output formatting
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;35m'
NC='\033[0m'  # No Color

# Script usage function
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTION]
Audit RHEL 9 system against CIS benchmarks.

Options:
    -h, --help              Display this help message
    --section1             Run only Section 1 (Initial Setup)
    --section2             Run only Section 2 (Services)
    --section3             Run only Section 3 (Network Configuration)
    --section4             Run only Section 4 (Logging and Auditing)
    --section5             Run only Section 5 (Access, Authentication and Authorization)
    --section6             Run only Section 6 (System Maintenance)
    --section7             Run only Section 7 (System File Permissions)
    --all                  Run all sections (default)
    --show-report         Show only the final report of a previous run
    --format=FORMAT       Output format (text, csv, json)

Example:
    $(basename "$0") --section1    # Run only Initial Setup checks
    $(basename "$0") --all         # Run all checks
    $(basename "$0") --show-report # Show last report

Report bugs to: your@email.com
EOF
    exit 1
}

# Initialize variables
AUDIT_MODE="all"
OUTPUT_FORMAT="text"
SHOW_REPORT=false

# Initialize counters
pass=0
fail=0

# Create audit directory if it doesn't exist
mkdir -p "$PWD/audit"

# Initialize result file
echo "Timestamp,Check Name,Status,Details" > "$PWD/audit/audit_results.csv"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            --section1)
                AUDIT_MODE="section1"
                ;;
            --section2)
                AUDIT_MODE="section2"
                ;;
            --section3)
                AUDIT_MODE="section3"
                ;;
            --section4)
                AUDIT_MODE="section4"
                ;;
            --section5)
                AUDIT_MODE="section5"
                ;;
            --section6)
                AUDIT_MODE="section6"
                ;;
            --section7)
                AUDIT_MODE="section7"
                ;;
            --all)
                AUDIT_MODE="all"
                ;;
            --show-report)
                SHOW_REPORT=true
                ;;
            --format=*)
                OUTPUT_FORMAT="${1#*=}"
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
        shift
    done
}

# Initialize counters
pass=0
fail=0

# Create audit directory if it doesn't exist
mkdir -p "$PWD/audit"

# Banner and Introduction
clear
echo -e "${RED}==================================================================${NC}"
echo -e "******************************************************************"
echo -e "******************** ${YELLOW}WELCOME${NC} *************************"
echo -e "*************** ${BLUE}Red-Hat 9 OS CIS Auditing${NC} ***********************"
echo -e "${RED}******************************************************************"
echo -e "${RED}==================================================================${NC}"
echo
echo -e "${YELLOW}WARNING:${NC} Please refrain from entering any commands or interfering with the execution of the audit script to ensure accurate results."
sleep 2

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to log results
log_result() {
    local check_name="$1"
    local status="$2"
    local details="$3"
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$check_name,$status,$details" >> "$PWD/audit/audit_results.csv"
}

# Initialize CSV results file
echo "Timestamp,Check Name,Status,Details" > "$PWD/audit/audit_results.csv"

# Function to check service status
check_service_status() {
    local service_name="$1"
    if systemctl is-enabled "$service_name" &>/dev/null; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

# Function to check file permissions
check_file_permissions() {
    local file="$1"
    local expected_perms="$2"
    local actual_perms

    if [ -f "$file" ]; then
        actual_perms=$(stat -c "%a" "$file")
        if [ "$actual_perms" = "$expected_perms" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to check kernel parameters
check_sysctl() {
    local param="$1"
    local expected="$2"
    local actual

    actual=$(sysctl -n "$param" 2>/dev/null)
    if [ "$actual" = "$expected" ]; then
        return 0
    fi
    return 1
}

# Main audit functions for each section
audit_section1_1_1() {
    echo -e "\n${BLUE}1.1.1 Configure Filesystem Kernel Modules${NC}"

    # 1.1.1.1 - 1.1.1.8 Ensure mounting of cramfs/freevxfs/jffs2/hfs/hfsplus/squashfs/udf/FAT filesystems is disabled
    local modules=("cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "squashfs" "udf" "vfat")
    for mod in "${modules[@]}"; do
        # Check if module is blacklisted
        if grep -q "^blacklist $mod" /etc/modprobe.d/* 2>/dev/null; then
            echo -e "${GREEN}PASS:${NC} $mod module is blacklisted"
            ((pass++))
            log_result "1.1.1 - $mod blacklist" "PASS" "Module is blacklisted"
        else
            echo -e "${RED}FAIL:${NC} $mod module is not blacklisted"
            ((fail++))
            log_result "1.1.1 - $mod blacklist" "FAIL" "Module is not blacklisted"
        fi

        # Check if module is loaded
        if ! lsmod | grep -q "^$mod\\s" 2>/dev/null; then
            echo -e "${GREEN}PASS:${NC} $mod module is not loaded"
            ((pass++))
            log_result "1.1.1 - $mod loaded" "PASS" "Module is not loaded"
        else
            echo -e "${RED}FAIL:${NC} $mod module is loaded"
            ((fail++))
            log_result "1.1.1 - $mod loaded" "FAIL" "Module is loaded"
        fi
    done
}

audit_section1_1_2() {
    echo -e "\n${BLUE}1.1.2 Configure Filesystem Mount Options${NC}"

    # Define array of mount points and their required options
    local mounts=(
        "/tmp:nodev,nosuid,noexec"
        "/var:nodev"
        "/var/tmp:nodev,nosuid,noexec"
        "/var/log:nodev,nosuid,noexec"
        "/var/log/audit:nodev,nosuid,noexec"
        "/home:nodev"
        "/dev/shm:nodev,nosuid,noexec"
    )

    for mount in "${mounts[@]}"; do
        local mp="${mount%%:*}"
        local options="${mount#*:}"
        local IFS=','
        local all_pass=true

        echo -e "\nChecking $mp mount options..."

        # Check if mount point exists
        if mount | grep -q "\\s${mp}\\s"; then
            for opt in $options; do
                if mount | grep "\\s${mp}\\s" | grep -q "$opt"; then
                    echo -e "${GREEN}PASS:${NC} $mp has $opt option"
                    log_result "1.1.2 - $mp $opt" "PASS" "Option is set"
                else
                    echo -e "${RED}FAIL:${NC} $mp missing $opt option"
                    all_pass=false
                    log_result "1.1.2 - $mp $opt" "FAIL" "Option is missing"
                fi
            done
        else
            echo -e "${YELLOW}WARN:${NC} $mp is not mounted"
            log_result "1.1.2 - $mp mount" "WARN" "Mount point does not exist"
            all_pass=false
        fi

        if [ "$all_pass" = true ]; then
            ((pass++))
        else
            ((fail++))
        fi
    done
}

audit_section1_2() {
    echo -e "\n${BLUE}1.2 Package Management${NC}"

    # 1.2.1 Configure DNF
    echo -e "\n${BLUE}1.2.1 Configure DNF${NC}"

    # 1.2.1.1 Ensure GPG keys are configured
    if rpm -q gpg-pubkey &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} GPG keys are configured"
        ((pass++))
        log_result "1.2.1.1" "PASS" "GPG keys are configured"
    else
        echo -e "${RED}FAIL:${NC} GPG keys are not configured"
        ((fail++))
        log_result "1.2.1.1" "FAIL" "GPG keys are not configured"
    fi

    # 1.2.1.2 Ensure gpgcheck is globally activated
    if grep -q '^gpgcheck=1' /etc/dnf/dnf.conf; then
        echo -e "${GREEN}PASS:${NC} gpgcheck is globally activated"
        ((pass++))
        log_result "1.2.1.2" "PASS" "gpgcheck is globally activated"
    else
        echo -e "${RED}FAIL:${NC} gpgcheck is not globally activated"
        ((fail++))
        log_result "1.2.1.2" "FAIL" "gpgcheck is not globally activated"
    fi

    # 1.2.1.3 Ensure package manager repositories are configured
    if dnf repolist &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} Package manager repositories are configured"
        ((pass++))
        log_result "1.2.1.3" "PASS" "Package manager repositories are configured"
    else
        echo -e "${RED}FAIL:${NC} Package manager repositories are not configured"
        ((fail++))
        log_result "1.2.1.3" "FAIL" "Package manager repositories are not configured"
    fi
}

audit_section1_3() {
    echo -e "\n${BLUE}1.3 SELinux${NC}"

    # 1.3.1 Ensure SELinux is installed
    if rpm -q libselinux &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} SELinux is installed"
        ((pass++))
        log_result "1.3.1" "PASS" "SELinux is installed"
    else
        echo -e "${RED}FAIL:${NC} SELinux is not installed"
        ((fail++))
        log_result "1.3.1" "FAIL" "SELinux is not installed"
    fi

    # 1.3.2 Ensure SELinux is in enforcing mode
    if getenforce | grep -q "Enforcing"; then
        echo -e "${GREEN}PASS:${NC} SELinux is in enforcing mode"
        ((pass++))
        log_result "1.3.2" "PASS" "SELinux is in enforcing mode"
    else
        echo -e "${RED}FAIL:${NC} SELinux is not in enforcing mode"
        ((fail++))
        log_result "1.3.2" "FAIL" "SELinux is not in enforcing mode"
    fi

    # 1.3.3 Ensure SELinux policy is configured
    if grep -q "^SELINUXTYPE=targeted" /etc/selinux/config; then
        echo -e "${GREEN}PASS:${NC} SELinux policy is configured to targeted"
        ((pass++))
        log_result "1.3.3" "PASS" "SELinux policy is configured to targeted"
    else
        echo -e "${RED}FAIL:${NC} SELinux policy is not configured to targeted"
        ((fail++))
        log_result "1.3.3" "FAIL" "SELinux policy is not configured to targeted"
    fi
}

audit_services() {
    echo -e "\n${BLUE}2. Services${NC}"

    # Check unnecessary services
    local services=("rsyncd" "squid" "snmpd" "ypserv" "rsh.socket" "telnet.socket")
    for svc in "${services[@]}"; do
        if [ "$(check_service_status "$svc")" = "disabled" ]; then
            echo -e "${GREEN}PASS:${NC} $svc is disabled"
            ((pass++))
        else
            echo -e "${RED}FAIL:${NC} $svc is enabled"
            ((fail++))
        fi
    done
}

audit_network_configuration() {
    echo -e "\n${BLUE}3. Network Configuration${NC}"

    # Function to check sysctl parameters
    check_sysctl_params() {
        local params=("$@")
        local all_pass=true

        for param in "${params[@]}"; do
            local key="${param%=*}"
            local value="${param#*=}"
            local current=$(sysctl -n "$key" 2>/dev/null)

            if [ "$current" = "$value" ]; then
                echo -e "${GREEN}PASS:${NC} $key is set to $value"
                log_result "3.1" "PASS" "$key is correctly set"
            else
                echo -e "${RED}FAIL:${NC} $key is set to $current, should be $value"
                log_result "3.1" "FAIL" "$key is incorrectly set"
                all_pass=false
            fi
        done

        [ "$all_pass" = true ] && ((pass++)) || ((fail++))
    }

    # 3.1 Network Protocol Security
    echo -e "\n${BLUE}3.1 Network Protocol Security${NC}"

    # 3.1.1 IPv4 Protocol Security
    local ipv4_params=(
        "net.ipv4.ip_forward=0"
        "net.ipv4.conf.all.send_redirects=0"
        "net.ipv4.conf.default.send_redirects=0"
        "net.ipv4.conf.all.accept_source_route=0"
        "net.ipv4.conf.default.accept_source_route=0"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.conf.default.accept_redirects=0"
        "net.ipv4.conf.all.secure_redirects=0"
        "net.ipv4.conf.default.secure_redirects=0"
        "net.ipv4.conf.all.log_martians=1"
        "net.ipv4.conf.default.log_martians=1"
        "net.ipv4.icmp_echo_ignore_broadcasts=1"
        "net.ipv4.icmp_ignore_bogus_error_responses=1"
        "net.ipv4.conf.all.rp_filter=1"
        "net.ipv4.conf.default.rp_filter=1"
        "net.ipv4.tcp_syncookies=1"
    )
    check_sysctl_params "${ipv4_params[@]}"

    # 3.1.2 IPv6 Protocol Security
    local ipv6_params=(
        "net.ipv6.conf.all.accept_ra=0"
        "net.ipv6.conf.default.accept_ra=0"
        "net.ipv6.conf.all.accept_redirects=0"
        "net.ipv6.conf.default.accept_redirects=0"
        "net.ipv6.conf.all.disable_ipv6=0"
        "net.ipv6.conf.default.disable_ipv6=0"
    )
    check_sysctl_params "${ipv6_params[@]}"

    # 3.2 Firewall Configuration
    echo -e "\n${BLUE}3.2 Firewall Configuration${NC}"

    # Check firewalld installation and status
    if rpm -q firewalld &>/dev/null; then
        if systemctl is-active firewalld &>/dev/null; then
            echo -e "${GREEN}PASS:${NC} firewalld is installed and active"
            ((pass++))
            log_result "3.2" "PASS" "firewalld is active"

            # Check default zone
            local default_zone=$(firewall-cmd --get-default-zone 2>/dev/null)
            if [ -n "$default_zone" ]; then
                echo -e "${GREEN}PASS:${NC} firewall default zone is set to $default_zone"
                ((pass++))
                log_result "3.2" "PASS" "Default zone is configured"
            else
                echo -e "${RED}FAIL:${NC} firewall default zone is not set"
                ((fail++))
                log_result "3.2" "FAIL" "Default zone not configured"
            fi
        else
            echo -e "${RED}FAIL:${NC} firewalld is not active"
            ((fail++))
            log_result "3.2" "FAIL" "firewalld is not active"
        fi
    else
        echo -e "${RED}FAIL:${NC} firewalld is not installed"
        ((fail++))
        log_result "3.2" "FAIL" "firewalld is not installed"
    fi

    # 3.3 TCP Wrappers
    echo -e "\n${BLUE}3.3 TCP Wrappers${NC}"

    local tcp_wrapper_files=("/etc/hosts.allow" "/etc/hosts.deny")
    for file in "${tcp_wrapper_files[@]}"; do
        if [ -f "$file" ]; then
            if [ "$(stat -c "%a" "$file")" = "644" ]; then
                echo -e "${GREEN}PASS:${NC} $file has correct permissions"
                ((pass++))
                log_result "3.3" "PASS" "$file is properly configured"
            else
                echo -e "${RED}FAIL:${NC} $file has incorrect permissions"
                ((fail++))
                log_result "3.3" "FAIL" "$file has incorrect permissions"
            fi
        else
            echo -e "${RED}FAIL:${NC} $file does not exist"
            ((fail++))
            log_result "3.3" "FAIL" "$file does not exist"
        fi
    done
}

audit_logging() {
    echo -e "\n${BLUE}4. Logging and Auditing${NC}"

    # Check rsyslog
    if command_exists rsyslog; then
        if [ "$(check_service_status rsyslog)" = "enabled" ]; then
            echo -e "${GREEN}PASS:${NC} rsyslog is enabled"
            ((pass++))
        else
            echo -e "${RED}FAIL:${NC} rsyslog is not enabled"
            ((fail++))
        fi
    fi

    # Check auditd
    if command_exists auditd; then
        if [ "$(check_service_status auditd)" = "enabled" ]; then
            echo -e "${GREEN}PASS:${NC} auditd is enabled"
            ((pass++))
        else
            echo -e "${RED}FAIL:${NC} auditd is not enabled"
            ((fail++))
        fi
    fi
}

audit_access_authentication() {
    echo -e "\n${BLUE}5. Access, Authentication and Authorization${NC}"

    # 5.1 Configure PAM
    echo -e "\n${BLUE}5.1 PAM Configuration${NC}"

    # Function to check PAM configuration
    check_pam_config() {
        local file="$1"
        local pattern="$2"
        local description="$3"
        local section="$4"

        if [ -f "$file" ]; then
            if grep -q "$pattern" "$file"; then
                echo -e "${GREEN}PASS:${NC} $description"
                ((pass++))
                log_result "$section" "PASS" "$description"
            else
                echo -e "${RED}FAIL:${NC} $description not found"
                ((fail++))
                log_result "$section" "FAIL" "$description not found"
            fi
        else
            echo -e "${RED}FAIL:${NC} $file does not exist"
            ((fail++))
            log_result "$section" "FAIL" "$file does not exist"
        fi
    }

    # 5.1.1 Password Quality Requirements
    local pwquality_params=(
        "minlen=14"
        "dcredit=-1"
        "ucredit=-1"
        "ocredit=-1"
        "lcredit=-1"
    )

    if [ -f "/etc/security/pwquality.conf" ]; then
        for param in "${pwquality_params[@]}"; do
            if grep -q "^${param}" /etc/security/pwquality.conf; then
                echo -e "${GREEN}PASS:${NC} Password quality: $param"
                ((pass++))
                log_result "5.1.1" "PASS" "Password quality $param configured"
            else
                echo -e "${RED}FAIL:${NC} Password quality: $param not set"
                ((fail++))
                log_result "5.1.1" "FAIL" "Password quality $param not configured"
            fi
        done
    fi

    # 5.1.2 PAM Authentication Modules
    local pam_files=(
        "/etc/pam.d/system-auth"
        "/etc/pam.d/password-auth"
    )

    for file in "${pam_files[@]}"; do
        # Check password hashing algorithm
        check_pam_config "$file" "password.*pam_unix.so.*sha512" "SHA512 password hashing" "5.1.2"

        # Check password reuse limits
        check_pam_config "$file" "password.*pam_unix.so.*remember=" "Password reuse limits" "5.1.2"

        # Check account lockout
        check_pam_config "$file" "auth.*pam_faillock.so" "Account lockout configuration" "5.1.2"
    done

    # 5.1.3 Password Aging Controls
    if [ -f "/etc/login.defs" ]; then
        local login_defs_params=(
            "PASS_MAX_DAYS\s*90"
            "PASS_MIN_DAYS\s*7"
            "PASS_WARN_AGE\s*7"
        )

        for param in "${login_defs_params[@]}"; do
            if grep -qE "^${param}" /etc/login.defs; then
                echo -e "${GREEN}PASS:${NC} Password aging: $param"
                ((pass++))
                log_result "5.1.3" "PASS" "Password aging $param configured"
            else
                echo -e "${RED}FAIL:${NC} Password aging: $param not set"
                ((fail++))
                log_result "5.1.3" "FAIL" "Password aging $param not configured"
            fi
        done
    fi

    # 5.2 SSH Configuration
    echo -e "\n${BLUE}5.2 SSH Configuration${NC}"

    if [ -f "/etc/ssh/sshd_config" ]; then
        local ssh_params=(
            "^PermitRootLogin\s*no"
            "^PasswordAuthentication\s*no"
            "^PermitEmptyPasswords\s*no"
            "^Protocol\s*2"
            "^X11Forwarding\s*no"
            "^MaxAuthTries\s*4"
            "^IgnoreRhosts\s*yes"
            "^HostbasedAuthentication\s*no"
            "^UsePAM\s*yes"
        )

        for param in "${ssh_params[@]}"; do
            if grep -qE "$param" /etc/ssh/sshd_config; then
                echo -e "${GREEN}PASS:${NC} SSH: $(echo $param | cut -d'\' -f1)"
                ((pass++))
                log_result "5.2" "PASS" "SSH $(echo $param | cut -d'\' -f1) configured"
            else
                echo -e "${RED}FAIL:${NC} SSH: $(echo $param | cut -d'\' -f1) not set"
                ((fail++))
                log_result "5.2" "FAIL" "SSH $(echo $param | cut -d'\' -f1) not configured"
            fi
        done
    fi
}

audit_section6_1() {
    echo -e "\n${BLUE}6.1 Configure Integrity Checking${NC}"

    # 6.1.1 Ensure AIDE is installed
    if rpm -q aide &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} AIDE is installed"
        ((pass++))
        log_result "6.1.1" "PASS" "AIDE is installed"
    else
        echo -e "${RED}FAIL:${NC} AIDE is not installed"
        ((fail++))
        log_result "6.1.1" "FAIL" "AIDE is not installed"
    fi

    # 6.1.2 Ensure filesystem integrity is regularly checked
    if grep -Ers '^([^#]+\s+)?(\/usr\/sbin\/)?aide\s+(--check|[-C])\b' /etc/cron.* /etc/crontab /var/spool/cron/ &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} AIDE file integrity check is scheduled"
        ((pass++))
        log_result "6.1.2" "PASS" "AIDE integrity check is scheduled"
    else
        echo -e "${RED}FAIL:${NC} AIDE file integrity check is not scheduled"
        ((fail++))
        log_result "6.1.2" "FAIL" "AIDE integrity check is not scheduled"
    fi

    # 6.1.3 Ensure cryptographic mechanisms are used to protect the integrity of audit tools
    local audit_tools=("/sbin/auditctl" "/sbin/auditd" "/sbin/ausearch" "/sbin/aureport" "/sbin/autrace" "/sbin/augenrules")
    local all_pass=true

    for tool in "${audit_tools[@]}"; do
        if [ -f "$tool" ]; then
            if aide --config /etc/aide/aide.conf -check | grep -q "$tool"; then
                echo -e "${GREEN}PASS:${NC} $tool is protected by AIDE"
                log_result "6.1.3" "PASS" "$tool is protected by AIDE"
            else
                echo -e "${RED}FAIL:${NC} $tool is not protected by AIDE"
                all_pass=false
                log_result "6.1.3" "FAIL" "$tool is not protected by AIDE"
            fi
        fi
    done

    if [ "$all_pass" = true ]; then
        ((pass++))
    else
        ((fail++))
    fi

    for entry in "${system_files[@]}"; do
        local file="${entry%:*}"
        local perms="${entry#*:}"
        if check_file_permissions "$file" "$perms"; then
            echo -e "${GREEN}PASS:${NC} $file has correct permissions"
            ((pass++))
        else
            echo -e "${RED}FAIL:${NC} $file has incorrect permissions"
            ((fail++))
        fi
    done
}

audit_section1_4() {
    echo -e "\n${BLUE}1.4 Bootloader Configuration${NC}"

    # 1.4.1 Ensure bootloader configuration is not publicly readable
    local grub_cfg="/boot/grub2/grub.cfg"
    local grub2_dir="/boot/grub2"
    local efi_dir="/boot/efi/EFI/redhat"

    # Check GRUB2 config file permissions
    local grub_files=("$grub_cfg" "$grub2_dir/grubenv" "$grub2_dir/user.cfg")
    [ -d "$efi_dir" ] && grub_files+=("$efi_dir/grub.cfg")

    for file in "${grub_files[@]}"; do
        if [ -f "$file" ]; then
            if check_file_permissions "$file" "600" "root" "root"; then
                echo -e "${GREEN}PASS:${NC} $file has correct permissions"
                ((pass++))
                log_result "1.4.1" "PASS" "$file has correct permissions"
            else
                echo -e "${RED}FAIL:${NC} $file has incorrect permissions"
                ((fail++))
                log_result "1.4.1" "FAIL" "$file has incorrect permissions"
            fi
        fi
    done

    # 1.4.2 Ensure bootloader password is set
    local password_found=0
    if [ -f "/boot/grub2/user.cfg" ]; then
        if grep -q "^GRUB2_PASSWORD=" /boot/grub2/user.cfg; then
            password_found=1
        fi
    fi
    if [ -f "$grub_cfg" ]; then
        if grep -q "password_pbkdf2" "$grub_cfg"; then
            password_found=1
        fi
    fi

    if [ $password_found -eq 1 ]; then
        echo -e "${GREEN}PASS:${NC} Bootloader password is set"
        ((pass++))
        log_result "1.4.2" "PASS" "Bootloader password is configured"
    else
        echo -e "${RED}FAIL:${NC} Bootloader password is not set"
        ((fail++))
        log_result "1.4.2" "FAIL" "Bootloader password is not configured"
    fi

    # 1.4.3 Ensure authentication required for single user mode
    if grep -q "^root:[*\!]:" /etc/shadow; then
        echo -e "${RED}FAIL:${NC} Root password is not set (required for single user mode)"
        ((fail++))
        log_result "1.4.3" "FAIL" "Root password not set"
    else
        echo -e "${GREEN}PASS:${NC} Root password is set"
        ((pass++))
        log_result "1.4.3" "PASS" "Root password is set"
    fi

    # 1.4.4 Ensure boot loader config is backed up
    if [ -f "${grub_cfg}.bak" ]; then
        echo -e "${GREEN}PASS:${NC} Boot loader config backup exists"
        ((pass++))
        log_result "1.4.4" "PASS" "Boot loader config backup exists"
    else
        echo -e "${YELLOW}WARN:${NC} No boot loader config backup found"
        log_result "1.4.4" "WARN" "No boot loader config backup"
    fi

    # 1.4.5 Check for custom boot parameters
    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub; then
        echo -e "${YELLOW}INFO:${NC} Custom boot parameters found - manual review required"
        log_result "1.4.5" "INFO" "Custom boot parameters present"
    fi
}

audit_section1_5() {
    echo -e "\n${BLUE}1.5 Process Hardening${NC}"

    # 1.5.1 Ensure address space layout randomization (ASLR) is enabled
    if check_sysctl "kernel.randomize_va_space" "2"; then
        echo -e "${GREEN}PASS:${NC} ASLR is enabled"
        ((pass++))
        log_result "1.5.1" "PASS" "ASLR is enabled"
    else
        echo -e "${RED}FAIL:${NC} ASLR is not enabled"
        ((fail++))
        log_result "1.5.1" "FAIL" "ASLR is not enabled"
    fi

    # 1.5.2 Ensure prelink is not installed
    if ! rpm -q prelink &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} prelink is not installed"
        ((pass++))
        log_result "1.5.2" "PASS" "prelink is not installed"
    else
        echo -e "${RED}FAIL:${NC} prelink is installed"
        ((fail++))
        log_result "1.5.2" "FAIL" "prelink is installed"
    fi
}

audit_section1_7() {
    echo -e "\n${BLUE}1.7 Warning Banners${NC}"

    # Function to check banner file
    check_banner_file() {
        local file="$1"
        local section="$2"

        if [ -f "$file" ]; then
            # Check permissions
            if check_file_permissions "$file" "644" "root" "root"; then
                # Check content
                if grep -q "Authorized" "$file" || grep -q "restricted" "$file"; then
                    echo -e "${GREEN}PASS:${NC} $file has appropriate content and permissions"
                    ((pass++))
                    log_result "$section" "PASS" "$file properly configured"
                else
                    echo -e "${YELLOW}WARN:${NC} $file may need content review"
                    log_result "$section" "WARN" "$file content needs review"
                fi
            else
                echo -e "${RED}FAIL:${NC} $file has incorrect permissions"
                ((fail++))
                log_result "$section" "FAIL" "$file has incorrect permissions"
            fi
        else
            echo -e "${RED}FAIL:${NC} $file does not exist"
            ((fail++))
            log_result "$section" "FAIL" "$file does not exist"
        fi
    }

    # 1.7.1 Ensure message of the day is configured properly
    check_banner_file "/etc/motd" "1.7.1"

    # 1.7.2 Ensure local login warning banner is configured properly
    check_banner_file "/etc/issue" "1.7.2"

    # 1.7.3 Ensure remote login warning banner is configured properly
    check_banner_file "/etc/issue.net" "1.7.3"

    # 1.7.4 Ensure permissions on /etc/motd are configured
    check_file_permissions "/etc/motd" "644" "root" "root" "1.7.4"

    # 1.7.5 Ensure permissions on /etc/issue are configured
    check_file_permissions "/etc/issue" "644" "root" "root" "1.7.5"

    # 1.7.6 Ensure permissions on /etc/issue.net are configured
    check_file_permissions "/etc/issue.net" "644" "root" "root" "1.7.6"

    # 1.7.7 Ensure GDM login banner is configured
    if [ -f "/etc/dconf/profile/gdm" ]; then
        if grep -q "banner-message-enable=true" /etc/dconf/db/gdm.d/*; then
            echo -e "${GREEN}PASS:${NC} GDM banner is enabled"
            ((pass++))
            log_result "1.7.7" "PASS" "GDM banner configured"
        else
            echo -e "${RED}FAIL:${NC} GDM banner is not configured"
            ((fail++))
            log_result "1.7.7" "FAIL" "GDM banner not configured"
        fi
    else
        echo -e "${YELLOW}INFO:${NC} GDM is not installed"
        log_result "1.7.7" "INFO" "GDM not installed"
    fi
}

audit_section1_6() {
    echo -e "\n${BLUE}1.6 Mandatory Access Control${NC}"

    # 1.6.1 Configure SELinux
    # 1.6.1.1 Ensure SELinux is not disabled in bootloader configuration
    if ! grep -q "selinux=0" /etc/default/grub && ! grep -q "enforcing=0" /etc/default/grub; then
        echo -e "${GREEN}PASS:${NC} SELinux is not disabled in bootloader configuration"
        ((pass++))
        log_result "1.6.1.1" "PASS" "SELinux is not disabled in bootloader"
    else
        echo -e "${RED}FAIL:${NC} SELinux is disabled in bootloader configuration"
        ((fail++))
        log_result "1.6.1.1" "FAIL" "SELinux is disabled in bootloader"
    fi

    # 1.6.1.2 Ensure SELinux state is enforcing
    if [ "$(getenforce)" = "Enforcing" ]; then
        echo -e "${GREEN}PASS:${NC} SELinux state is enforcing"
        ((pass++))
        log_result "1.6.1.2" "PASS" "SELinux state is enforcing"
    else
        echo -e "${RED}FAIL:${NC} SELinux state is not enforcing"
        ((fail++))
        log_result "1.6.1.2" "FAIL" "SELinux state is not enforcing"
    fi

    # 1.6.1.3 Ensure SELinux policy is configured
    if grep -q "^SELINUXTYPE=targeted" /etc/selinux/config; then
        echo -e "${GREEN}PASS:${NC} SELinux policy is configured correctly"
        ((pass++))
        log_result "1.6.1.3" "PASS" "SELinux policy is set to targeted"
    else
        echo -e "${RED}FAIL:${NC} SELinux policy is not configured correctly"
        ((fail++))
        log_result "1.6.1.3" "FAIL" "SELinux policy is not set to targeted"
    fi
}

audit_section3_1() {
    echo -e "\n${BLUE}3.1 Network Parameters (Host Only)${NC}"

    # 3.1.1 Ensure IP forwarding is disabled
    if check_sysctl "net.ipv4.ip_forward" "0" && check_sysctl "net.ipv6.conf.all.forwarding" "0"; then
        echo -e "${GREEN}PASS:${NC} IP forwarding is disabled"
        ((pass++))
        log_result "3.1.1" "PASS" "IP forwarding is disabled"
    else
        echo -e "${RED}FAIL:${NC} IP forwarding is enabled"
        ((fail++))
        log_result "3.1.1" "FAIL" "IP forwarding is enabled"
    fi

    # 3.1.2 Ensure packet redirect sending is disabled
    local redirect_params=(
        "net.ipv4.conf.all.send_redirects=0"
        "net.ipv4.conf.default.send_redirects=0"
    )

    local all_pass=true
    for param in "${redirect_params[@]}"; do
        local key="${param%=*}"
        local value="${param#*=}"
        if ! check_sysctl "$key" "$value"; then
            all_pass=false
            break
        fi
    done

    if [ "$all_pass" = true ]; then
        echo -e "${GREEN}PASS:${NC} Packet redirect sending is disabled"
        ((pass++))
        log_result "3.1.2" "PASS" "Packet redirect sending is disabled"
    else
        echo -e "${RED}FAIL:${NC} Packet redirect sending is enabled"
        ((fail++))
        log_result "3.1.2" "FAIL" "Packet redirect sending is enabled"
    fi
}

audit_section3_2() {
    echo -e "\n${BLUE}3.2 Network Parameters (Host and Router)${NC}"

    local network_params=(
        "net.ipv4.conf.all.accept_source_route=0"
        "net.ipv4.conf.default.accept_source_route=0"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.conf.default.accept_redirects=0"
        "net.ipv4.conf.all.secure_redirects=0"
        "net.ipv4.conf.default.secure_redirects=0"
        "net.ipv4.conf.all.log_martians=1"
        "net.ipv4.conf.default.log_martians=1"
        "net.ipv4.icmp_echo_ignore_broadcasts=1"
        "net.ipv4.icmp_ignore_bogus_error_responses=1"
        "net.ipv4.conf.all.rp_filter=1"
        "net.ipv4.conf.default.rp_filter=1"
        "net.ipv4.tcp_syncookies=1"
    )

    for param in "${network_params[@]}"; do
        local key="${param%=*}"
        local value="${param#*=}"
        if check_sysctl "$key" "$value"; then
            echo -e "${GREEN}PASS:${NC} $key is set to $value"
            ((pass++))
            log_result "3.2 - $key" "PASS" "Parameter correctly set"
        else
            echo -e "${RED}FAIL:${NC} $key is not set to $value"
            ((fail++))
            log_result "3.2 - $key" "FAIL" "Parameter incorrectly set"
        fi
    done
}

audit_section3_3() {
    echo -e "\n${BLUE}3.3 TCP Wrappers${NC}"

    # 3.3.1 Ensure TCP Wrappers is installed
    if rpm -q tcp_wrappers &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} TCP Wrappers is installed"
        ((pass++))
        log_result "3.3.1" "PASS" "TCP Wrappers is installed"
    else
        echo -e "${RED}FAIL:${NC} TCP Wrappers is not installed"
        ((fail++))
        log_result "3.3.1" "FAIL" "TCP Wrappers is not installed"
    fi

    # 3.3.2 Ensure /etc/hosts.allow is configured
    if [ -f "/etc/hosts.allow" ] && [ -s "/etc/hosts.allow" ]; then
        echo -e "${GREEN}PASS:${NC} /etc/hosts.allow exists and is not empty"
        ((pass++))
        log_result "3.3.2" "PASS" "/etc/hosts.allow is configured"
    else
        echo -e "${RED}FAIL:${NC} /etc/hosts.allow is missing or empty"
        ((fail++))
        log_result "3.3.2" "FAIL" "/etc/hosts.allow is not configured"
    fi

    # 3.3.3 Ensure /etc/hosts.deny is configured
    if [ -f "/etc/hosts.deny" ] && grep -q "ALL: ALL" "/etc/hosts.deny"; then
        echo -e "${GREEN}PASS:${NC} /etc/hosts.deny is configured with ALL: ALL"
        ((pass++))
        log_result "3.3.3" "PASS" "/etc/hosts.deny is configured correctly"
    else
        echo -e "${RED}FAIL:${NC} /etc/hosts.deny is not configured with ALL: ALL"
        ((fail++))
        log_result "3.3.3" "FAIL" "/etc/hosts.deny is not configured correctly"
    fi
}

audit_section3_4() {
    echo -e "\n${BLUE}3.4 Uncommon Network Protocols${NC}"

    local protocols=("dccp" "sctp" "rds" "tipc")
    for protocol in "${protocols[@]}"; do
        if ! grep -q "^install $protocol /bin/true" /etc/modprobe.d/* 2>/dev/null; then
            echo -e "${RED}FAIL:${NC} $protocol protocol is not disabled"
            ((fail++))
            log_result "3.4 - $protocol" "FAIL" "Protocol is not disabled"
        else
            echo -e "${GREEN}PASS:${NC} $protocol protocol is disabled"
            ((pass++))
            log_result "3.4 - $protocol" "PASS" "Protocol is disabled"
        fi
    done
}

audit_section3_5() {
    echo -e "\n${BLUE}3.5 Firewall Configuration${NC}"

    # 3.5.1 Ensure firewalld is installed
    if rpm -q firewalld &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} firewalld is installed"
        ((pass++))
        log_result "3.5.1" "PASS" "firewalld is installed"

        # 3.5.2 Ensure firewalld service is enabled and running
        if systemctl is-enabled firewalld &>/dev/null && systemctl is-active firewalld &>/dev/null; then
            echo -e "${GREEN}PASS:${NC} firewalld is enabled and running"
            ((pass++))
            log_result "3.5.2" "PASS" "firewalld is enabled and running"
        else
            echo -e "${RED}FAIL:${NC} firewalld is not enabled or not running"
            ((fail++))
            log_result "3.5.2" "FAIL" "firewalld is not enabled or not running"
        fi

        # 3.5.3 Ensure default zone is set
        if firewall-cmd --get-default-zone &>/dev/null; then
            echo -e "${GREEN}PASS:${NC} firewalld default zone is set"
            ((pass++))
            log_result "3.5.3" "PASS" "Default zone is set"
        else
            echo -e "${RED}FAIL:${NC} firewalld default zone is not set"
            ((fail++))
            log_result "3.5.3" "FAIL" "Default zone is not set"
        fi
    else
        echo -e "${RED}FAIL:${NC} firewalld is not installed"
        ((fail++))
        log_result "3.5.1" "FAIL" "firewalld is not installed"
    fi
}

audit_section4_1() {
    echo -e "\n${BLUE}4.1 Configure System Accounting (auditd)${NC}"

    # 4.1.1 Ensure auditd is installed
    if rpm -q audit &>/dev/null && rpm -q audit-libs &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} auditd is installed"
        ((pass++))
        log_result "4.1.1" "PASS" "auditd is installed"

        # 4.1.2 Ensure auditd service is enabled and running
        if systemctl is-enabled auditd &>/dev/null && systemctl is-active auditd &>/dev/null; then
            echo -e "${GREEN}PASS:${NC} auditd service is enabled and running"
            ((pass++))
            log_result "4.1.2" "PASS" "auditd service is enabled and running"
        else
            echo -e "${RED}FAIL:${NC} auditd service is not enabled or not running"
            ((fail++))
            log_result "4.1.2" "FAIL" "auditd service is not enabled or not running"
        fi

        # 4.1.3 Ensure audit logs are configured
        if grep -q "^max_log_file[[:space:]]*=" /etc/audit/auditd.conf; then
            echo -e "${GREEN}PASS:${NC} Audit logs are configured"
            ((pass++))
            log_result "4.1.3" "PASS" "Audit logs are configured"
        else
            echo -e "${RED}FAIL:${NC} Audit logs are not configured"
            ((fail++))
            log_result "4.1.3" "FAIL" "Audit logs are not configured"
        fi

        # 4.1.4 Ensure audit_backlog_limit is sufficient
        if grep -q "^audit_backlog_limit=" /etc/default/grub; then
            echo -e "${GREEN}PASS:${NC} audit_backlog_limit is configured"
            ((pass++))
            log_result "4.1.4" "PASS" "audit_backlog_limit is configured"
        else
            echo -e "${RED}FAIL:${NC} audit_backlog_limit is not configured"
            ((fail++))
            log_result "4.1.4" "FAIL" "audit_backlog_limit is not configured"
        fi
    else
        echo -e "${RED}FAIL:${NC} auditd is not installed"
        ((fail++))
        log_result "4.1.1" "FAIL" "auditd is not installed"
    fi
}

audit_section4_2() {
    echo -e "\n${BLUE}4.2 Configure Logging${NC}"

    # 4.2.1 Configure rsyslog
    # 4.2.1.1 Ensure rsyslog is installed
    if rpm -q rsyslog &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} rsyslog is installed"
        ((pass++))
        log_result "4.2.1.1" "PASS" "rsyslog is installed"

        # 4.2.1.2 Ensure rsyslog service is enabled
        if systemctl is-enabled rsyslog &>/dev/null; then
            echo -e "${GREEN}PASS:${NC} rsyslog service is enabled"
            ((pass++))
            log_result "4.2.1.2" "PASS" "rsyslog service is enabled"
        else
            echo -e "${RED}FAIL:${NC} rsyslog service is not enabled"
            ((fail++))
            log_result "4.2.1.2" "FAIL" "rsyslog service is not enabled"
        fi

        # 4.2.1.3 Ensure rsyslog default file permissions are configured
        if grep -q "^\\$FileCreateMode" /etc/rsyslog.conf; then
            echo -e "${GREEN}PASS:${NC} rsyslog default file permissions configured"
            ((pass++))
            log_result "4.2.1.3" "PASS" "rsyslog default file permissions configured"
        else
            echo -e "${RED}FAIL:${NC} rsyslog default file permissions not configured"
            ((fail++))
            log_result "4.2.1.3" "FAIL" "rsyslog default file permissions not configured"
        fi

        # 4.2.1.4 Ensure logging is configured
        local log_files=("/var/log/messages" "/var/log/secure" "/var/log/maillog" "/var/log/cron")
        for log_file in "${log_files[@]}"; do
            if [ -f "$log_file" ]; then
                echo -e "${GREEN}PASS:${NC} $log_file exists"
                ((pass++))
                log_result "4.2.1.4" "PASS" "$log_file exists"
            else
                echo -e "${RED}FAIL:${NC} $log_file does not exist"
                ((fail++))
                log_result "4.2.1.4" "FAIL" "$log_file does not exist"
            fi
        done
    else
        echo -e "${RED}FAIL:${NC} rsyslog is not installed"
        ((fail++))
        log_result "4.2.1.1" "FAIL" "rsyslog is not installed"
    fi
}

audit_section4_3() {
    echo -e "\n${BLUE}4.3 Ensure logrotate is configured${NC}"

    # Check if logrotate is installed
    if rpm -q logrotate &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} logrotate is installed"
        ((pass++))
        log_result "4.3.1" "PASS" "logrotate is installed"

audit_section6_2_2() {
    echo -e "\n${BLUE}6.2.2 Configure journald${NC}"

    # 6.2.2.1.1 Ensure systemd-journal-remote is installed
    if rpm -q systemd-journal-remote &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} systemd-journal-remote is installed"
        ((pass++))
        log_result "6.2.2.1.1" "PASS" "systemd-journal-remote is installed"
    else
        echo -e "${RED}FAIL:${NC} systemd-journal-remote is not installed"
        ((fail++))
        log_result "6.2.2.1.1" "FAIL" "systemd-journal-remote is not installed"
    fi

    # 6.2.2.1.2 Ensure systemd-journal-upload authentication is configured
    if [ -f "/etc/systemd/journal-upload.conf" ] && grep -q "^URL=" "/etc/systemd/journal-upload.conf"; then
        echo -e "${GREEN}PASS:${NC} systemd-journal-upload authentication is configured"
        ((pass++))
        log_result "6.2.2.1.2" "PASS" "systemd-journal-upload authentication is configured"
    else
        echo -e "${RED}FAIL:${NC} systemd-journal-upload authentication is not configured"
        ((fail++))
        log_result "6.2.2.1.2" "FAIL" "systemd-journal-upload authentication is not configured"
    fi

    # 6.2.2.1.3 Ensure systemd-journal-upload is enabled and active
    if systemctl is-enabled systemd-journal-upload &>/dev/null && systemctl is-active systemd-journal-upload &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} systemd-journal-upload is enabled and active"
        ((pass++))
        log_result "6.2.2.1.3" "PASS" "systemd-journal-upload is enabled and active"
    else
        echo -e "${RED}FAIL:${NC} systemd-journal-upload is not enabled or active"
        ((fail++))
        log_result "6.2.2.1.3" "FAIL" "systemd-journal-upload is not enabled or active"
    fi

    # 6.2.2.1.4 Ensure systemd-journal-remote service is not in use
    if ! systemctl is-enabled systemd-journal-remote &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} systemd-journal-remote service is not in use"
        ((pass++))
        log_result "6.2.2.1.4" "PASS" "systemd-journal-remote service is not in use"
    else
        echo -e "${RED}FAIL:${NC} systemd-journal-remote service is in use"
        ((fail++))
        log_result "6.2.2.1.4" "FAIL" "systemd-journal-remote service is in use"
    fi

    # 6.2.2.2 Ensure journald ForwardToSyslog is disabled
    if grep -q "^ForwardToSyslog=no" /etc/systemd/journald.conf; then
        echo -e "${GREEN}PASS:${NC} journald ForwardToSyslog is disabled"
        ((pass++))
        log_result "6.2.2.2" "PASS" "ForwardToSyslog is disabled"
    else
        echo -e "${RED}FAIL:${NC} journald ForwardToSyslog is not disabled"
        ((fail++))
        log_result "6.2.2.2" "FAIL" "ForwardToSyslog is not disabled"
    fi

    # 6.2.2.3 Ensure journald Compress is configured
    if grep -q "^Compress=yes" /etc/systemd/journald.conf; then
        echo -e "${GREEN}PASS:${NC} journald Compress is configured"
        ((pass++))
        log_result "6.2.2.3" "PASS" "Compress is configured"
    else
        echo -e "${RED}FAIL:${NC} journald Compress is not configured"
        ((fail++))
        log_result "6.2.2.3" "FAIL" "Compress is not configured"
    fi

    # 6.2.2.4 Ensure journald Storage is configured
    if grep -q "^Storage=persistent" /etc/systemd/journald.conf; then
        echo -e "${GREEN}PASS:${NC} journald Storage is configured"
        ((pass++))
        log_result "6.2.2.4" "PASS" "Storage is configured"
    else
        echo -e "${RED}FAIL:${NC} journald Storage is not configured"
        ((fail++))
        log_result "6.2.2.4" "FAIL" "Storage is not configured"
    fi
}

audit_section6_2_3() {
    echo -e "\n${BLUE}6.2.3 Configure rsyslog${NC}"

    # 6.2.3.1 Ensure rsyslog is installed
    if rpm -q rsyslog &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} rsyslog is installed"
        ((pass++))
        log_result "6.2.3.1" "PASS" "rsyslog is installed"
    else
        echo -e "${RED}FAIL:${NC} rsyslog is not installed"
        ((fail++))
        log_result "6.2.3.1" "FAIL" "rsyslog is not installed"
    fi

    # 6.2.3.2 Ensure rsyslog service is enabled and active
    if systemctl is-enabled rsyslog &>/dev/null && systemctl is-active rsyslog &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} rsyslog service is enabled and active"
        ((pass++))
        log_result "6.2.3.2" "PASS" "rsyslog service is enabled and active"
    else
        echo -e "${RED}FAIL:${NC} rsyslog service is not enabled or active"
        ((fail++))
        log_result "6.2.3.2" "FAIL" "rsyslog service is not enabled or active"
    fi

    # 6.2.3.3 Ensure journald is configured to send logs to rsyslog
    if grep -q "^ForwardToSyslog=yes" /etc/systemd/journald.conf; then
        echo -e "${GREEN}PASS:${NC} journald is configured to send logs to rsyslog"
        ((pass++))
        log_result "6.2.3.3" "PASS" "journald forwards to rsyslog"
    else
        echo -e "${RED}FAIL:${NC} journald is not configured to send logs to rsyslog"
        ((fail++))
        log_result "6.2.3.3" "FAIL" "journald does not forward to rsyslog"
    fi

    # 6.2.3.4 Ensure rsyslog log file creation mode is configured
    if grep -q "^FileCreateMode" /etc/rsyslog.conf; then
        local mode=$(grep "^FileCreateMode" /etc/rsyslog.conf | awk '{print $2}')
        if [ "$mode" = "0600" ] || [ "$mode" = "0640" ]; then
            echo -e "${GREEN}PASS:${NC} rsyslog log file creation mode is configured securely"
            ((pass++))
            log_result "6.2.3.4" "PASS" "Log file creation mode is secure"
        else
            echo -e "${RED}FAIL:${NC} rsyslog log file creation mode is not secure"
            ((fail++))
            log_result "6.2.3.4" "FAIL" "Log file creation mode is not secure"
        fi
    else
        echo -e "${RED}FAIL:${NC} rsyslog log file creation mode is not configured"
        ((fail++))
        log_result "6.2.3.4" "FAIL" "Log file creation mode is not configured"
    fi

    # 6.2.3.5 Ensure rsyslog logging is configured
    if [ -f "/etc/rsyslog.conf" ] && [ -d "/etc/rsyslog.d" ]; then
        if grep -q "^*.*[^I][^I]*@" /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null; then
            echo -e "${GREEN}PASS:${NC} rsyslog logging is configured"
            ((pass++))
            log_result "6.2.3.5" "PASS" "rsyslog logging is configured"
        else
            echo -e "${RED}FAIL:${NC} rsyslog logging is not configured"
            ((fail++))
            log_result "6.2.3.5" "FAIL" "rsyslog logging is not configured"
        fi
    fi

    # 6.2.3.6 Ensure rsyslog is configured to send logs to a remote log host
    if grep -q "^*.*[^I][^I]*@" /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null; then
        echo -e "${GREEN}PASS:${NC} rsyslog is configured to send logs to a remote host"
        ((pass++))
        log_result "6.2.3.6" "PASS" "Remote logging is configured"
    else
        echo -e "${RED}FAIL:${NC} rsyslog is not configured to send logs to a remote host"
        ((fail++))
        log_result "6.2.3.6" "FAIL" "Remote logging is not configured"
    fi

    # 6.2.3.7 Ensure rsyslog is not configured to receive logs from a remote client
    if ! grep -q "^$ModLoad.*imtcp" /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null; then
        echo -e "${GREEN}PASS:${NC} rsyslog is not configured to receive remote logs"
        ((pass++))
        log_result "6.2.3.7" "PASS" "Not configured to receive remote logs"
    else
        echo -e "${RED}FAIL:${NC} rsyslog is configured to receive remote logs"
        ((fail++))
        log_result "6.2.3.7" "FAIL" "Configured to receive remote logs"
    fi

    # 6.2.3.8 Ensure rsyslog logrotate is configured
    if [ -f "/etc/logrotate.d/rsyslog" ]; then
        echo -e "${GREEN}PASS:${NC} rsyslog logrotate is configured"
        ((pass++))
        log_result "6.2.3.8" "PASS" "logrotate is configured"
    else
        echo -e "${RED}FAIL:${NC} rsyslog logrotate is not configured"
        ((fail++))
        log_result "6.2.3.8" "FAIL" "logrotate is not configured"
    fi
}

audit_section6_3_1() {
    echo -e "\n${BLUE}6.3.1 Configure auditd Service${NC}"

    # 6.3.1.1 Ensure auditd packages are installed
    if rpm -q audit audit-libs &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} auditd packages are installed"
        ((pass++))
        log_result "6.3.1.1" "PASS" "auditd packages are installed"
    else
        echo -e "${RED}FAIL:${NC} auditd packages are not installed"
        ((fail++))
        log_result "6.3.1.1" "FAIL" "auditd packages are not installed"
    fi

    # 6.3.1.2 Ensure auditing for processes that start prior to auditd is enabled
    if grep -q "^GRUB_CMDLINE_LINUX.*audit=1" /etc/default/grub; then
        echo -e "${GREEN}PASS:${NC} Early boot auditing is enabled"
        ((pass++))
        log_result "6.3.1.2" "PASS" "Early boot auditing is enabled"
    else
        echo -e "${RED}FAIL:${NC} Early boot auditing is not enabled"
        ((fail++))
        log_result "6.3.1.2" "FAIL" "Early boot auditing is not enabled"
    fi

    # 6.3.1.3 Ensure audit_backlog_limit is sufficient
    if grep -q "^GRUB_CMDLINE_LINUX.*audit_backlog_limit=" /etc/default/grub; then
        local limit=$(grep "^GRUB_CMDLINE_LINUX" /etc/default/grub | grep -o 'audit_backlog_limit=[0-9]*' | cut -d= -f2)
        if [ -n "$limit" ] && [ "$limit" -ge 8192 ]; then
            echo -e "${GREEN}PASS:${NC} audit_backlog_limit is sufficient"
            ((pass++))
            log_result "6.3.1.3" "PASS" "audit_backlog_limit is sufficient"
        else
            echo -e "${RED}FAIL:${NC} audit_backlog_limit is insufficient"
            ((fail++))
            log_result "6.3.1.3" "FAIL" "audit_backlog_limit is insufficient"
        fi
    else
        echo -e "${RED}FAIL:${NC} audit_backlog_limit is not set"
        ((fail++))
        log_result "6.3.1.3" "FAIL" "audit_backlog_limit is not set"
    fi

    # 6.3.1.4 Ensure auditd service is enabled and active
    if systemctl is-enabled auditd &>/dev/null && systemctl is-active auditd &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} auditd service is enabled and active"
        ((pass++))
        log_result "6.3.1.4" "PASS" "auditd service is enabled and active"
    else
        echo -e "${RED}FAIL:${NC} auditd service is not enabled or active"
        ((fail++))
        log_result "6.3.1.4" "FAIL" "auditd service is not enabled or active"
    fi
}

audit_section6_3_2() {
    echo -e "\n${BLUE}6.3.2 Configure Data Retention${NC}"

    # 6.3.2.1 Ensure audit log storage size is configured
    if grep -q "^max_log_file[[:space:]]" /etc/audit/auditd.conf; then
        echo -e "${GREEN}PASS:${NC} Audit log storage size is configured"
        ((pass++))
        log_result "6.3.2.1" "PASS" "Audit log storage size is configured"
    else
        echo -e "${RED}FAIL:${NC} Audit log storage size is not configured"
        ((fail++))
        log_result "6.3.2.1" "FAIL" "Audit log storage size is not configured"
    fi

    # 6.3.2.2 Ensure audit logs are not automatically deleted
    if grep -q "^max_log_file_action[[:space:]]*=[[:space:]]*keep_logs" /etc/audit/auditd.conf; then
        echo -e "${GREEN}PASS:${NC} Audit logs are not automatically deleted"
        ((pass++))
        log_result "6.3.2.2" "PASS" "Audit logs are not automatically deleted"
    else
        echo -e "${RED}FAIL:${NC} Audit logs might be automatically deleted"
        ((fail++))
        log_result "6.3.2.2" "FAIL" "Audit logs might be automatically deleted"
    fi

    # 6.3.2.3 Ensure system is disabled when audit logs are full
    local space_left_action=$(grep "^space_left_action" /etc/audit/auditd.conf | awk '{print $3}')
    local disk_full_action=$(grep "^disk_full_action" /etc/audit/auditd.conf | awk '{print $3}')
    local disk_error_action=$(grep "^disk_error_action" /etc/audit/auditd.conf | awk '{print $3}')

    if [ "$space_left_action" = "email" ] && [ "$disk_full_action" = "halt" ] && [ "$disk_error_action" = "halt" ]; then
        echo -e "${GREEN}PASS:${NC} System is configured to disable when audit logs are full"
        ((pass++))
        log_result "6.3.2.3" "PASS" "System will disable when audit logs are full"
    else
        echo -e "${RED}FAIL:${NC} System is not configured to disable when audit logs are full"
        ((fail++))
        log_result "6.3.2.3" "FAIL" "System will not disable when audit logs are full"
    fi

    # 6.3.2.4 Ensure system warns when audit logs are low on space
    if grep -q "^space_left[[:space:]]" /etc/audit/auditd.conf; then
        echo -e "${GREEN}PASS:${NC} System is configured to warn when audit logs are low on space"
        ((pass++))
        log_result "6.3.2.4" "PASS" "System will warn when audit logs are low on space"
    else
        echo -e "${RED}FAIL:${NC} System is not configured to warn when audit logs are low on space"
        ((fail++))
        log_result "6.3.2.4" "FAIL" "System will not warn when audit logs are low on space"
    fi
}

audit_section6_3_3() {
    echo -e "\n${BLUE}6.3.3 Configure auditd Rules${NC}"

    # Function to check audit rules
    check_audit_rule() {
        local rule="$1"
        local description="$2"
        local section="$3"

        if auditctl -l | grep -q -- "$rule"; then
            echo -e "${GREEN}PASS:${NC} $description"
            ((pass++))
            log_result "$section" "PASS" "$description"
        else
            echo -e "${RED}FAIL:${NC} $description"
            ((fail++))
            log_result "$section" "FAIL" "$description"
        fi
    }

    # 6.3.3.1 Ensure changes to system administration scope are collected
    check_audit_rule "-w /etc/sudoers -p wa" "Sudoers file changes are monitored" "6.3.3.1"
    check_audit_rule "-w /etc/sudoers.d/ -p wa" "Sudoers.d directory changes are monitored" "6.3.3.1"

    # 6.3.3.2 Ensure actions as another user are logged
    check_audit_rule "-p x -F auid!=unset -F auid>=1000 -F auid!=4294967295 -C auid!=obj_uid -F key=user_emulation" \
        "Actions as another user are logged" "6.3.3.2"

    # 6.3.3.3 Ensure sudo log file is collected
    check_audit_rule "-w /var/log/sudo.log -p wa" "Sudo log file changes are collected" "6.3.3.3"

    # 6.3.3.4 Ensure date and time changes are collected
    check_audit_rule "-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -F key=time-change" \
        "Time change events are collected" "6.3.3.4"
    check_audit_rule "-w /etc/localtime -p wa -k time-change" "Localtime changes are monitored" "6.3.3.4"

    # 6.3.3.5 Ensure network environment changes are collected
    local network_rules=(
        "-a always,exit -F arch=b64 -S sethostname,setdomainname -F key=system-locale"
        "-w /etc/issue -p wa -k system-locale"
        "-w /etc/issue.net -p wa -k system-locale"
        "-w /etc/hosts -p wa -k system-locale"
        "-w /etc/network -p wa -k system-locale"
    )
    for rule in "${network_rules[@]}"; do
        check_audit_rule "$rule" "Network environment changes are collected" "6.3.3.5"
    done

    # 6.3.3.6 Ensure use of privileged commands is collected
    find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | while read -r cmd; do
        check_audit_rule "-a always,exit -F path=$cmd -F perm=x -F auid>=1000 -F auid!=unset -F key=privileged" \
            "Privileged command $cmd is monitored" "6.3.3.6"
    done

    # 6.3.3.7 Ensure unsuccessful file access attempts are collected
    local access_rules=(
        "-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=unset -F key=access"
        "-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=unset -F key=access"
    )
    for rule in "${access_rules[@]}"; do
        check_audit_rule "$rule" "Unsuccessful file access attempts are collected" "6.3.3.7"
    done

    # Continue with remaining rules 6.3.3.8 through 6.3.3.21
    # 6.3.3.8 Ensure user/group changes are collected
    check_audit_rule "-w /etc/group -p wa -k identity" "Group file changes are collected" "6.3.3.8"
    check_audit_rule "-w /etc/passwd -p wa -k identity" "Password file changes are collected" "6.3.3.8"
    check_audit_rule "-w /etc/gshadow -p wa -k identity" "GShadow file changes are collected" "6.3.3.8"
    check_audit_rule "-w /etc/shadow -p wa -k identity" "Shadow file changes are collected" "6.3.3.8"
    check_audit_rule "-w /etc/security/opasswd -p wa -k identity" "OPasswd file changes are collected" "6.3.3.8"

    # 6.3.3.9 Ensure DAC permission modifications are collected
    local dac_rules=(
        "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -F key=perm_mod"
        "-a always,exit -F arch=b64 -S chown,fchown,lchown,fchownat -F auid>=1000 -F auid!=unset -F key=perm_mod"
        "-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -F key=perm_mod"
    )
    for rule in "${dac_rules[@]}"; do
        check_audit_rule "$rule" "DAC permission modifications are collected" "6.3.3.9"
    done

    # 6.3.3.10 through 6.3.3.20 (Adding remaining rules...)
    # 6.3.3.10 Ensure successful file system mounts are collected
    check_audit_rule "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=unset -F key=mounts" \
        "Successful file system mounts are collected" "6.3.3.10"

    # 6.3.3.11 Ensure session initiation information is collected
    check_audit_rule "-w /var/run/utmp -p wa -k session" "Session initiation information is collected" "6.3.3.11"
    check_audit_rule "-w /var/log/wtmp -p wa -k session" "Session initiation information is collected" "6.3.3.11"
    check_audit_rule "-w /var/log/btmp -p wa -k session" "Session initiation information is collected" "6.3.3.11"

    # 6.3.3.20 Ensure the audit configuration is immutable
    if grep -q "^\s*-e\s+2\s*$" /etc/audit/rules.d/99-finalize.rules 2>/dev/null; then
        echo -e "${GREEN}PASS:${NC} Audit configuration is immutable"
        ((pass++))
        log_result "6.3.3.20" "PASS" "Audit configuration is immutable"
    else
        echo -e "${RED}FAIL:${NC} Audit configuration is not immutable"
        ((fail++))
        log_result "6.3.3.20" "FAIL" "Audit configuration is not immutable"
    fi

    # 6.3.3.21 Ensure the running and on disk configuration is the same
    if auditctl -s | grep -q "enabled=2"; then
        echo -e "${GREEN}PASS:${NC} Running and on disk audit configuration match"
        ((pass++))
        log_result "6.3.3.21" "PASS" "Running and on disk audit configuration match"
    else
        echo -e "${RED}FAIL:${NC} Running and on disk audit configuration do not match"
        ((fail++))
        log_result "6.3.3.21" "FAIL" "Running and on disk audit configuration do not match"
    fi
}

audit_section6_3_4() {
    echo -e "\n${BLUE}6.3.4 Configure auditd File Access${NC}"

    # Function to check file permissions and ownership
    check_audit_file() {
        local file="$1"
        local expected_mode="$2"
        local expected_owner="$3"
        local expected_group="$4"
        local section="$5"
        local description="$6"

        if [ -f "$file" ]; then
            local mode=$(stat -c "%a" "$file")
            local owner=$(stat -c "%U" "$file")
            local group=$(stat -c "%G" "$file")

            if [ "$mode" = "$expected_mode" ] && [ "$owner" = "$expected_owner" ] && [ "$group" = "$expected_group" ]; then
                echo -e "${GREEN}PASS:${NC} $description"
                ((pass++))
                log_result "$section" "PASS" "$description"
            else
                echo -e "${RED}FAIL:${NC} $description (mode=$mode owner=$owner group=$group)"
                ((fail++))
                log_result "$section" "FAIL" "$description"
            fi
        else
            echo -e "${RED}FAIL:${NC} $file does not exist"
            ((fail++))
            log_result "$section" "FAIL" "$file does not exist"
        fi
    }

    # 6.3.4.1 Ensure audit log directory has appropriate permissions
    check_audit_file "/var/log/audit" "750" "root" "root" "6.3.4.1" "Audit log directory permissions"

    # 6.3.4.2 Ensure audit log files have appropriate permissions
    find /var/log/audit/ -type f -name "audit*" | while read -r file; do
        check_audit_file "$file" "600" "root" "root" "6.3.4.2" "Audit log file permissions"
    done

    # 6.3.4.3 Ensure audit log files are owned by root
    find /var/log/audit/ -type f -name "audit*" | while read -r file; do
        check_audit_file "$file" "600" "root" "root" "6.3.4.3" "Audit log file ownership"
    done

    # 6.3.4.4 Ensure audit log files group is root
    find /var/log/audit/ -type f -name "audit*" | while read -r file; do
        check_audit_file "$file" "600" "root" "root" "6.3.4.4" "Audit log file group ownership"
    done

    # 6.3.4.5 Ensure audit configuration files have appropriate permissions
    check_audit_file "/etc/audit/auditd.conf" "640" "root" "root" "6.3.4.5" "Audit config file permissions"

    # 6.3.4.6 Ensure audit configuration files are owned by root
    find /etc/audit/ -type f | while read -r file; do
        check_audit_file "$file" "640" "root" "root" "6.3.4.6" "Audit config file ownership"
    done

    # 6.3.4.7 Ensure audit configuration files group is root
    find /etc/audit/ -type f | while read -r file; do
        check_audit_file "$file" "640" "root" "root" "6.3.4.7" "Audit config file group ownership"
    done

    # 6.3.4.8 Ensure audit tools have appropriate permissions
    local audit_tools=("/sbin/auditctl" "/sbin/aureport" "/sbin/ausearch" "/sbin/autrace" "/sbin/auditd" "/sbin/augenrules")
    for tool in "${audit_tools[@]}"; do
        check_audit_file "$tool" "750" "root" "root" "6.3.4.8" "Audit tool permissions"
    done

    # 6.3.4.9 Ensure audit tools are owned by root
    for tool in "${audit_tools[@]}"; do
        check_audit_file "$tool" "750" "root" "root" "6.3.4.9" "Audit tool ownership"
    done

    # 6.3.4.10 Ensure audit tools group is root
    for tool in "${audit_tools[@]}"; do
        check_audit_file "$tool" "750" "root" "root" "6.3.4.10" "Audit tool group ownership"
    done
}

audit_section7_1() {
    echo -e "\n${BLUE}7.1 System File Permissions${NC}"

    # Function to check file permissions and ownership
    check_file_permissions() {
        local file="$1"
        local expected_perms="$2"
        local expected_owner="$3"
        local expected_group="$4"
        local section="$5"

        if [ -f "$file" ]; then
            local perms=$(stat -c "%a" "$file")
            local owner=$(stat -c "%U" "$file")
            local group=$(stat -c "%G" "$file")

            if [ "$perms" = "$expected_perms" ] && [ "$owner" = "$expected_owner" ] && [ "$group" = "$expected_group" ]; then
                echo -e "${GREEN}PASS:${NC} $file has correct permissions and ownership"
                ((pass++))
                log_result "$section" "PASS" "$file has correct permissions"
            else
                echo -e "${RED}FAIL:${NC} $file has incorrect permissions or ownership (found: $perms:$owner:$group)"
                ((fail++))
                log_result "$section" "FAIL" "$file has incorrect permissions"
            fi
        else
            echo -e "${YELLOW}WARN:${NC} $file does not exist"
            log_result "$section" "WARN" "$file does not exist"
        fi
    }

    # 7.1.1 Ensure permissions on /etc/passwd are configured
    check_file_permissions "/etc/passwd" "644" "root" "root" "7.1.1"

    # 7.1.2 Ensure permissions on /etc/passwd- are configured
    check_file_permissions "/etc/passwd-" "644" "root" "root" "7.1.2"

    # 7.1.3 Ensure permissions on /etc/group are configured
    check_file_permissions "/etc/group" "644" "root" "root" "7.1.3"

    # 7.1.4 Ensure permissions on /etc/group- are configured
    check_file_permissions "/etc/group-" "644" "root" "root" "7.1.4"

    # 7.1.5 Ensure permissions on /etc/shadow are configured
    check_file_permissions "/etc/shadow" "640" "root" "shadow" "7.1.5"

    # 7.1.6 Ensure permissions on /etc/shadow- are configured
    check_file_permissions "/etc/shadow-" "640" "root" "shadow" "7.1.6"

    # 7.1.7 Ensure permissions on /etc/gshadow are configured
    check_file_permissions "/etc/gshadow" "640" "root" "shadow" "7.1.7"

    # 7.1.8 Ensure permissions on /etc/gshadow- are configured
    check_file_permissions "/etc/gshadow-" "640" "root" "shadow" "7.1.8"

    # 7.1.9 Ensure permissions on /etc/shells are configured
    check_file_permissions "/etc/shells" "644" "root" "root" "7.1.9"

    # 7.1.10 Ensure permissions on /etc/security/opasswd are configured
    check_file_permissions "/etc/security/opasswd" "600" "root" "root" "7.1.10"

    # 7.1.11 Ensure world writable files and directories are secured
    echo -e "\nChecking for world-writable files..."
    if df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type f -perm -0002 2>/dev/null | grep -q .; then
        echo -e "${RED}FAIL:${NC} World writable files exist"
        ((fail++))
        log_result "7.1.11" "FAIL" "World writable files exist"
    else
        echo -e "${GREEN}PASS:${NC} No world writable files found"
        ((pass++))
        log_result "7.1.11" "PASS" "No world writable files found"
    fi

    # 7.1.12 Ensure no files or directories without owner/group exist
    echo -e "\nChecking for unowned files and directories..."
    if df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -nouser -o -nogroup 2>/dev/null | grep -q .; then
        echo -e "${RED}FAIL:${NC} Files or directories without owner/group exist"
        ((fail++))
        log_result "7.1.12" "FAIL" "Files without owner/group exist"
    else
        echo -e "${GREEN}PASS:${NC} No files or directories without owner/group found"
        ((pass++))
        log_result "7.1.12" "PASS" "No files without owner/group found"
    fi

    # 7.1.13 Ensure SUID and SGID files are reviewed
    echo -e "\nListing SUID/SGID files for review..."
    df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | while read -r file; do
        echo "Found SUID/SGID file: $file"
    done
    log_result "7.1.13" "INFO" "SUID/SGID files listed for manual review"
}

audit_section7_2() {
    echo -e "\n${BLUE}7.2 Local User and Group Settings${NC}"

    # 7.2.1 Ensure accounts in /etc/passwd use shadowed passwords
    echo -e "\nChecking for non-shadowed passwords..."
    if ! awk -F: '($2 != "x" ) { print $1 " is not set to use shadow passwords"}' /etc/passwd | grep -q .; then
        echo -e "${GREEN}PASS:${NC} All accounts use shadowed passwords"
        ((pass++))
        log_result "7.2.1" "PASS" "All accounts use shadowed passwords"
    else
        echo -e "${RED}FAIL:${NC} Some accounts do not use shadowed passwords"
        ((fail++))
        log_result "7.2.1" "FAIL" "Non-shadowed passwords found"
    fi

    # 7.2.2 Ensure /etc/shadow password fields are not empty
    echo -e "\nChecking for empty password fields..."
    if ! awk -F: '($2 == "" ) { print $1 " has an empty password"}' /etc/shadow | grep -q .; then
        echo -e "${GREEN}PASS:${NC} No empty password fields found"
        ((pass++))
        log_result "7.2.2" "PASS" "No empty password fields"
    else
        echo -e "${RED}FAIL:${NC} Empty password fields found"
        ((fail++))
        log_result "7.2.2" "FAIL" "Empty password fields exist"
    fi

    # 7.2.3 Ensure all groups in /etc/passwd exist in /etc/group
    echo -e "\nChecking for consistency between passwd and group files..."
    local missing_groups=0
    for gid in $(cut -d: -f4 /etc/passwd | sort -u); do
        grep -q "^[^:]*:[^:]*:$gid:" /etc/group || missing_groups=1
    done
    if [ $missing_groups -eq 0 ]; then
        echo -e "${GREEN}PASS:${NC} All groups in /etc/passwd exist in /etc/group"
        ((pass++))
        log_result "7.2.3" "PASS" "Groups consistent between passwd and group"
    else
        echo -e "${RED}FAIL:${NC} Some groups in /etc/passwd do not exist in /etc/group"
        ((fail++))
        log_result "7.2.3" "FAIL" "Inconsistent groups found"
    fi

    # 7.2.4 Ensure no duplicate UIDs exist
    echo -e "\nChecking for duplicate UIDs..."
    if ! cut -f3 -d":" /etc/passwd | sort -n | uniq -d | grep -q .; then
        echo -e "${GREEN}PASS:${NC} No duplicate UIDs found"
        ((pass++))
        log_result "7.2.4" "PASS" "No duplicate UIDs"
    else
        echo -e "${RED}FAIL:${NC} Duplicate UIDs found"
        ((fail++))
        log_result "7.2.4" "FAIL" "Duplicate UIDs exist"
    fi

    # 7.2.5 Ensure no duplicate GIDs exist
    echo -e "\nChecking for duplicate GIDs..."
    if ! cut -f3 -d":" /etc/group | sort -n | uniq -d | grep -q .; then
        echo -e "${GREEN}PASS:${NC} No duplicate GIDs found"
        ((pass++))
        log_result "7.2.5" "PASS" "No duplicate GIDs"
    else
        echo -e "${RED}FAIL:${NC} Duplicate GIDs found"
        ((fail++))
        log_result "7.2.5" "FAIL" "Duplicate GIDs exist"
    fi

    # 7.2.6 Ensure no duplicate user names exist
    echo -e "\nChecking for duplicate user names..."
    if ! cut -f1 -d":" /etc/passwd | sort -n | uniq -d | grep -q .; then
        echo -e "${GREEN}PASS:${NC} No duplicate user names found"
        ((pass++))
        log_result "7.2.6" "PASS" "No duplicate user names"
    else
        echo -e "${RED}FAIL:${NC} Duplicate user names found"
        ((fail++))
        log_result "7.2.6" "FAIL" "Duplicate user names exist"
    fi

    # 7.2.7 Ensure no duplicate group names exist
    echo -e "\nChecking for duplicate group names..."
    if ! cut -f1 -d":" /etc/group | sort -n | uniq -d | grep -q .; then
        echo -e "${GREEN}PASS:${NC} No duplicate group names found"
        ((pass++))
        log_result "7.2.7" "PASS" "No duplicate group names"
    else
        echo -e "${RED}FAIL:${NC} Duplicate group names found"
        ((fail++))
        log_result "7.2.7" "FAIL" "Duplicate group names exist"
    fi

    # 7.2.8 Ensure local interactive user home directories are configured
    echo -e "\nChecking user home directories..."
    local home_issues=0
    awk -F: '($3>=1000)&&($7!~/nologin|false|null/){print $1,$6}' /etc/passwd | while read -r user dir; do
        [ ! -d "$dir" ] && echo "The home directory ($dir) of user $user does not exist." && home_issues=1
    done
    if [ $home_issues -eq 0 ]; then
        echo -e "${GREEN}PASS:${NC} All user home directories exist and are configured"
        ((pass++))
        log_result "7.2.8" "PASS" "User home directories properly configured"
    else
        echo -e "${RED}FAIL:${NC} Some user home directories are missing or misconfigured"
        ((fail++))
        log_result "7.2.8" "FAIL" "Home directory issues found"
    fi

    # 7.2.9 Ensure local interactive user dot files access is configured
    echo -e "\nChecking user dot file permissions..."
    local dot_file_issues=0
    awk -F: '($3>=1000)&&($7!~/nologin|false|null/){print $1,$6}' /etc/passwd | while read -r user dir; do
        if [ -d "$dir" ]; then
            for file in "$dir"/.*; do
                if [ -f "$file" ]; then
                    perms=$(stat -L -c "%a" "$file")
                    if [ $(( $perms & 0022 )) -ne 0 ]; then
                        echo "User $user dot file $file is group/world writable"
                        dot_file_issues=1
                    fi
                fi
            done
        fi
    done
    if [ $dot_file_issues -eq 0 ]; then
        echo -e "${GREEN}PASS:${NC} All user dot files have appropriate permissions"
        ((pass++))
        log_result "7.2.9" "PASS" "User dot files properly configured"
    else
        echo -e "${RED}FAIL:${NC} Some user dot files have inappropriate permissions"
        ((fail++))
        log_result "7.2.9" "FAIL" "Dot file permission issues found"
    fi
}

audit_section6_2_4() {
    echo -e "\n${BLUE}6.2.4 Configure Logfiles${NC}"

    # 6.2.4.1 Ensure access to all logfiles has been configured
    local log_dirs=("/var/log" "/var/log/audit" "/var/log/journal")
    local all_pass=true

    for dir in "${log_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local perms=$(stat -c "%a" "$dir")
            if [ "$perms" = "750" ] || [ "$perms" = "755" ]; then
                echo -e "${GREEN}PASS:${NC} $dir has correct permissions ($perms)"
                log_result "6.2.4.1" "PASS" "$dir has correct permissions"
            else
                echo -e "${RED}FAIL:${NC} $dir has incorrect permissions ($perms)"
                all_pass=false
                log_result "6.2.4.1" "FAIL" "$dir has incorrect permissions"
            fi
        fi
    done

    find /var/log -type f -exec stat -c "%n %a" {} \; | while read -r file perms; do
        if [ "$perms" -gt "644" ]; then
            echo -e "${RED}FAIL:${NC} $file has excessive permissions ($perms)"
            all_pass=false
            log_result "6.2.4.1" "FAIL" "$file has excessive permissions"
        fi
    done

    if [ "$all_pass" = true ]; then
        ((pass++))
    else
        ((fail++))
    fi
}

        # Check logrotate configuration
        if [ -f "/etc/logrotate.conf" ]; then
            if grep -q "^weekly" /etc/logrotate.conf || \
               grep -q "^monthly" /etc/logrotate.conf || \
               grep -q "^yearly" /etc/logrotate.conf; then
                echo -e "${GREEN}PASS:${NC} logrotate rotation schedule is configured"
                ((pass++))
                log_result "4.3.2" "PASS" "logrotate rotation schedule is configured"
            else
                echo -e "${RED}FAIL:${NC} logrotate rotation schedule is not configured"
                ((fail++))
                log_result "4.3.2" "FAIL" "logrotate rotation schedule is not configured"
            fi
        else
            echo -e "${RED}FAIL:${NC} /etc/logrotate.conf does not exist"
            ((fail++))
            log_result "4.3.2" "FAIL" "/etc/logrotate.conf does not exist"
        fi
    else
        echo -e "${RED}FAIL:${NC} logrotate is not installed"
        ((fail++))
        log_result "4.3.1" "FAIL" "logrotate is not installed"
    fi
}

audit_section5_1() {
    echo -e "\n${BLUE}5.1 Configure time-based job schedulers${NC}"

    # 5.1.1 Ensure cron daemon is enabled and running
    if systemctl is-enabled crond &>/dev/null && systemctl is-active crond &>/dev/null; then
        echo -e "${GREEN}PASS:${NC} cron daemon is enabled and running"
        ((pass++))
        log_result "5.1.1" "PASS" "cron daemon is enabled and running"
    else
        echo -e "${RED}FAIL:${NC} cron daemon is not enabled or not running"
        ((fail++))
        log_result "5.1.1" "FAIL" "cron daemon is not enabled or not running"
    fi

    # 5.1.2 Ensure permissions on /etc/crontab are configured
    if check_file_permissions "/etc/crontab" "600"; then
        echo -e "${GREEN}PASS:${NC} /etc/crontab permissions are correct"
        ((pass++))
        log_result "5.1.2" "PASS" "/etc/crontab permissions are 600"
    else
        echo -e "${RED}FAIL:${NC} /etc/crontab permissions are incorrect"
        ((fail++))
        log_result "5.1.2" "FAIL" "/etc/crontab permissions are not 600"
    fi

    # 5.1.3-7 Ensure permissions on cron directories are configured
    local cron_dirs=("/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly" "/etc/cron.d")
    for dir in "${cron_dirs[@]}"; do
        if [ -d "$dir" ] && [ "$(stat -c "%a" "$dir")" = "700" ]; then
            echo -e "${GREEN}PASS:${NC} $dir permissions are correct"
            ((pass++))
            log_result "5.1.3-7" "PASS" "$dir permissions are 700"
        else
            echo -e "${RED}FAIL:${NC} $dir permissions are incorrect"
            ((fail++))
            log_result "5.1.3-7" "FAIL" "$dir permissions are not 700"
        fi
    done
}

audit_section5_2() {
    echo -e "\n${BLUE}5.2 Configure SSH Server${NC}"

    # Check if SSH is installed
    if [ -f "/etc/ssh/sshd_config" ]; then
        local ssh_params=(
            "Protocol 2"
            "LogLevel INFO"
            "X11Forwarding no"
            "MaxAuthTries 4"
            "IgnoreRhosts yes"
            "HostbasedAuthentication no"
            "PermitRootLogin no"
            "PermitEmptyPasswords no"
            "PermitUserEnvironment no"
            "ClientAliveInterval 300"
            "ClientAliveCountMax 0"
            "LoginGraceTime 60"
            "Banner /etc/issue.net"
            "UsePAM yes"
        )

        for param in "${ssh_params[@]}"; do
            local key="${param%% *}"
            local value="${param#* }"
            if grep -q "^${key} ${value}" /etc/ssh/sshd_config; then
                echo -e "${GREEN}PASS:${NC} SSH $key is set to $value"
                ((pass++))
                log_result "5.2 - $key" "PASS" "SSH parameter correctly set"
            else
                echo -e "${RED}FAIL:${NC} SSH $key is not set to $value"
                ((fail++))
                log_result "5.2 - $key" "FAIL" "SSH parameter incorrectly set"
            fi
        done
    else
        echo -e "${YELLOW}INFO:${NC} SSH server is not installed"
        log_result "5.2" "INFO" "SSH server is not installed"
    fi
}

audit_section5_3() {
    echo -e "\n${BLUE}5.3 Configure PAM and Password Settings${NC}"

    # 5.3.1 Ensure password creation requirements are configured
    if [ -f "/etc/security/pwquality.conf" ]; then
        local pwd_params=(
            "minlen=14"
            "dcredit=-1"
            "ucredit=-1"
            "ocredit=-1"
            "lcredit=-1"
        )

        for param in "${pwd_params[@]}"; do
            if grep -q "^${param}" /etc/security/pwquality.conf; then
                echo -e "${GREEN}PASS:${NC} Password requirement ${param} is set"
                ((pass++))
                log_result "5.3.1" "PASS" "Password requirement ${param} is set"
            else
                echo -e "${RED}FAIL:${NC} Password requirement ${param} is not set"
                ((fail++))
                log_result "5.3.1" "FAIL" "Password requirement ${param} is not set"
            fi
        done
    fi

    # 5.3.2 Ensure lockout for failed password attempts is configured
    if grep -q "pam_faillock.so" /etc/pam.d/password-auth && \
       grep -q "pam_faillock.so" /etc/pam.d/system-auth; then
        echo -e "${GREEN}PASS:${NC} Password lockout is configured"
        ((pass++))
        log_result "5.3.2" "PASS" "Password lockout is configured"
    else
        echo -e "${RED}FAIL:${NC} Password lockout is not configured"
        ((fail++))
        log_result "5.3.2" "FAIL" "Password lockout is not configured"
    fi
}

audit_section5_4() {
    echo -e "\n${BLUE}5.4 Configure User Accounts and Environment${NC}"

    # 5.4.1 Set Shadow Password Suite Parameters
    local shadow_params=(
        "PASS_MAX_DAYS 90"
        "PASS_MIN_DAYS 7"
        "PASS_WARN_AGE 7"
    )

    for param in "${shadow_params[@]}"; do
        if grep -q "^${param}" /etc/login.defs; then
            echo -e "${GREEN}PASS:${NC} Shadow password parameter ${param} is set"
            ((pass++))
            log_result "5.4.1" "PASS" "Shadow password parameter ${param} is set"
        else
            echo -e "${RED}FAIL:${NC} Shadow password parameter ${param} is not set"
            ((fail++))
            log_result "5.4.1" "FAIL" "Shadow password parameter ${param} is not set"
        fi
    done

    # 5.4.2 Ensure system accounts are secured
    awk -F: '($3 < 1000) {print $1}' /etc/passwd | while read -r user; do
        if [ "$user" != "root" ] && [ "$(grep "^$user:" /etc/shadow | cut -d: -f2)" != "*" ] && \
           [ "$(grep "^$user:" /etc/shadow | cut -d: -f2)" != "!!" ]; then
            echo -e "${RED}FAIL:${NC} System account $user is not secured"
            ((fail++))
            log_result "5.4.2" "FAIL" "System account $user is not secured"
        else
            echo -e "${GREEN}PASS:${NC} System account $user is secured"
            ((pass++))
            log_result "5.4.2" "PASS" "System account $user is secured"
        fi
    done
}

audit_section5_5() {
    echo -e "\n${BLUE}5.5 Configure Root Access${NC}"

    # 5.5.1 Ensure root login is restricted to system console
    if [ -f "/etc/securetty" ]; then
        if [ ! -s "/etc/securetty" ]; then
            echo -e "${GREEN}PASS:${NC} Root login is restricted to system console"
            ((pass++))
            log_result "5.5.1" "PASS" "Root login is restricted"
        else
            echo -e "${YELLOW}WARN:${NC} Review root login restrictions in /etc/securetty"
            log_result "5.5.1" "WARN" "Review /etc/securetty contents"
        fi
    fi

    # 5.5.2 Ensure access to su command is restricted
    if grep -q "^auth.*required.*pam_wheel.so.*use_uid" /etc/pam.d/su; then
        echo -e "${GREEN}PASS:${NC} Access to su command is restricted"
        ((pass++))
        log_result "5.5.2" "PASS" "su command access is restricted"
    else
        echo -e "${RED}FAIL:${NC} Access to su command is not restricted"
        ((fail++))
        log_result "5.5.2" "FAIL" "su command access is not restricted"
    fi
}

audit_section6_1() {
    echo -e "\n${BLUE}6.1 System File Permissions${NC}"

    # 6.1.1 Audit system file permissions
    local system_files=(
        "/etc/passwd:644:root:root"
        "/etc/shadow:000:root:root"
        "/etc/group:644:root:root"
        "/etc/gshadow:000:root:root"
        "/etc/passwd-:600:root:root"
        "/etc/shadow-:600:root:root"
        "/etc/group-:600:root:root"
        "/etc/gshadow-:600:root:root"
    )

    for entry in "${system_files[@]}"; do
        local file="${entry%%:*}"
        local perms="${entry#*:}"; perms="${perms%%:*}"
        local owner="${entry#*:*:}"; owner="${owner%%:*}"
        local group="${entry##*:}"

        if [ -f "$file" ]; then
            local actual_perms=$(stat -c "%a" "$file")
            local actual_owner=$(stat -c "%U" "$file")
            local actual_group=$(stat -c "%G" "$file")

            if [ "$actual_perms" = "$perms" ] && [ "$actual_owner" = "$owner" ] && [ "$actual_group" = "$group" ]; then
                echo -e "${GREEN}PASS:${NC} $file has correct permissions and ownership"
                ((pass++))
                log_result "6.1.1" "PASS" "$file has correct permissions and ownership"
            else
                echo -e "${RED}FAIL:${NC} $file has incorrect permissions or ownership"
                ((fail++))
                log_result "6.1.1" "FAIL" "$file has incorrect permissions or ownership"
            fi
        fi
    done
}

audit_section6_2() {
    echo -e "\n${BLUE}6.2 User and Group Settings${NC}"

    # 6.2.1 Ensure password fields are not empty
    if ! awk -F: '($2 == "" ) { print $1 " does not have a password "}' /etc/shadow | grep -q .; then
        echo -e "${GREEN}PASS:${NC} No empty password fields found"
        ((pass++))
        log_result "6.2.1" "PASS" "No empty password fields"
    else
        echo -e "${RED}FAIL:${NC} Empty password fields found"
        ((fail++))
        log_result "6.2.1" "FAIL" "Empty password fields exist"
    fi

    # 6.2.2 Ensure root is the only UID 0 account
    if [ "$(awk -F: '($3 == 0) { print $1 }' /etc/passwd)" = "root" ]; then
        echo -e "${GREEN}PASS:${NC} root is the only UID 0 account"
        ((pass++))
        log_result "6.2.2" "PASS" "root is only UID 0 account"
    else
        echo -e "${RED}FAIL:${NC} Other UID 0 accounts exist"
        ((fail++))
        log_result "6.2.2" "FAIL" "Multiple UID 0 accounts exist"
    fi
}

audit_section7_1() {
    echo -e "\n${BLUE}7.1 System File Permissions${NC}"

    # 7.1.1 Ensure message of the day is properly configured
    if [ -f "/etc/motd" ]; then
        if ! grep -q -i "\\v|\\r|\\m|\\s" /etc/motd; then
            echo -e "${GREEN}PASS:${NC} MOTD is properly configured"
            ((pass++))
            log_result "7.1.1" "PASS" "MOTD properly configured"
        else
            echo -e "${RED}FAIL:${NC} MOTD contains system information"
            ((fail++))
            log_result "7.1.1" "FAIL" "MOTD contains system information"
        fi
    fi

    # 7.1.2 Ensure permissions on /etc/motd are configured
    if [ -f "/etc/motd" ] && check_file_permissions "/etc/motd" "644"; then
        echo -e "${GREEN}PASS:${NC} /etc/motd has correct permissions"
        ((pass++))
        log_result "7.1.2" "PASS" "/etc/motd permissions correct"
    else
        echo -e "${RED}FAIL:${NC} /etc/motd has incorrect permissions"
        ((fail++))
        log_result "7.1.2" "FAIL" "/etc/motd permissions incorrect"
    fi
}

audit_section7_2() {
    echo -e "\n${BLUE}7.2 Update Management${NC}"

    # 7.2.1 Ensure dnf check-update is running
    if dnf check-update &>/dev/null; then
        local update_count=$(dnf check-update --quiet | grep -v "^$" | wc -l)
        if [ "$update_count" -eq 0 ]; then
            echo -e "${GREEN}PASS:${NC} System is up to date"
            ((pass++))
            log_result "7.2.1" "PASS" "No updates required"
        else
            echo -e "${RED}FAIL:${NC} System has $update_count updates available"
            ((fail++))
            log_result "7.2.1" "FAIL" "$update_count updates available"
        fi
    fi
}

audit_section7_3() {
    echo -e "\n${BLUE}7.3 Check for Unconfined Daemons${NC}"

    # Check for unconfined daemons
    if ps -eZ | grep -q unconfined_service_t; then
        echo -e "${RED}FAIL:${NC} Unconfined daemons found"
        ((fail++))
        log_result "7.3" "FAIL" "Unconfined daemons exist"
    else
        echo -e "${GREEN}PASS:${NC} No unconfined daemons found"
        ((pass++))
        log_result "7.3" "PASS" "No unconfined daemons"
    fi
}

audit_section7_4() {
    echo -e "\n${BLUE}7.4 Check for SUID/SGID Binaries${NC}"

    # Create a baseline of SUID/SGID files for review
    local suid_files=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null)
    if [ -n "$suid_files" ]; then
        echo -e "${YELLOW}WARN:${NC} SUID/SGID files found. Manual review required."
        echo "$suid_files" > "$PWD/audit/suid_sgid_files.txt"
        log_result "7.4" "WARN" "SUID/SGID files found - manual review required"
    else
        echo -e "${GREEN}PASS:${NC} No unexpected SUID/SGID files found"
        ((pass++))
        log_result "7.4" "PASS" "No unexpected SUID/SGID files"
    fi
}

# Function to check if a section was already run today
check_section_status() {
    local section=$1
    local status_file="/var/log/cis_audit/${section}_last_run"
    local today=$(date +%Y%m%d)

    # Create status directory if it doesn't exist
    mkdir -p "/var/log/cis_audit"

    # Check if the section was run today
    if [ -f "$status_file" ] && [ "$(cat "$status_file")" = "$today" ]; then
        return 0
    fi
    return 1
}

# Function to mark section as run
mark_section_complete() {
    local section=$1
    local status_file="/var/log/cis_audit/${section}_last_run"
    date +%Y%m%d > "$status_file"
}

# Main execution
main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Show report if requested
    if [ "$SHOW_REPORT" = true ]; then
        show_last_report
        exit 0
    fi

    echo -e "${BLUE}Starting CIS RHEL 9 Level 1 Security Audit${NC}"
    echo -e "${YELLOW}Running in mode: $AUDIT_MODE${NC}\n"

    # Initialize result directory
    mkdir -p "$PWD/audit"

    # Initialize CSV results file if not showing report
    if [ "$SHOW_REPORT" = false ]; then
        echo "Timestamp,Check Name,Status,Details,Section" > "$PWD/audit/audit_results.csv"
    fi

    # Function to run section checks
    run_section() {
        local section=$1
        local skip_if_run=${2:-false}

        if [ "$skip_if_run" = true ] && check_section_status "$section"; then
            echo -e "${YELLOW}Section $section was already checked today. Skipping...${NC}"
            return
        fi

        case $section in
            section1)
                echo -e "\n${BLUE}Section 1: Initial Setup${NC}"
                audit_section1_1_1  # Filesystem Configuration - Kernel Modules
                audit_section1_1_2  # Filesystem Configuration - Mount Options
                audit_section1_2    # Package Management
                audit_section1_3    # SELinux Configuration
                audit_section1_4    # Bootloader Configuration
                audit_section1_5    # Process Hardening
                audit_section1_6    # Mandatory Access Control
                audit_section1_7    # Warning Banners
                audit_section1_8    # GNOME Display Manager
                mark_section_complete "section1"
                ;;
            section2)
                echo -e "\n${BLUE}Section 2: Services${NC}"
                audit_services
                mark_section_complete "section2"
                ;;
            section3)
                echo -e "\n${BLUE}Section 3: Network Configuration${NC}"
                audit_network_configuration
                mark_section_complete "section3"
                ;;
            section4)
                echo -e "\n${BLUE}Section 4: Logging and Auditing${NC}"
                audit_logging
                mark_section_complete "section4"
                ;;
            section5)
                echo -e "\n${BLUE}Section 5: Access, Authentication and Authorization${NC}"
                audit_access_authentication
                mark_section_complete "section5"
                ;;
            section6)
                echo -e "\n${BLUE}Section 6: System Maintenance${NC}"
                audit_system_maintenance
                mark_section_complete "section6"
                ;;
            section7)
                echo -e "\n${BLUE}Section 7: System File Permissions${NC}"
                audit_section7_1
                audit_section7_2
                mark_section_complete "section7"
                ;;
        esac
    }

    # Execute requested sections
    case $AUDIT_MODE in
        all)
            for section in section{1..7}; do
                run_section "$section" true
            done
            ;;
        section*)
            run_section "$AUDIT_MODE" false
            ;;
    esac

    # Print summary at the end
    echo -e "\n${BLUE}=== Audit Summary ===${NC}"
    echo -e "${GREEN}Passed:${NC} $pass checks"
    echo -e "${RED}Failed:${NC} $fail checks"
    echo -e "\nDetailed results have been saved to: $PWD/audit/audit_results.csv"
}

# Function to show the last report
show_last_report() {
    local report_file="$PWD/audit/audit_results.csv"

    if [ ! -f "$report_file" ]; then
        echo -e "${RED}No audit report found.${NC}"
        exit 1
    fi

    case $OUTPUT_FORMAT in
        text)
            echo -e "${BLUE}=== CIS Audit Report ===${NC}"
            awk -F',' 'NR>1 {
                printf "\n%s:\n", $2;
                printf "Status: %s\n", $3;
                printf "Details: %s\n", $4;
                printf "Section: %s\n", $5;
            }' "$report_file"
            ;;
        csv)
            cat "$report_file"
            ;;
        json)
            echo "["
            awk -F',' 'NR>1 {
                printf "%s{\"check\":\"%s\",\"status\":\"%s\",\"details\":\"%s\",\"section\":\"%s\"}",
                    (NR>2?",":""), $2, $3, $4, $5
            }' "$report_file"
            echo "]"
            ;;
        *)
            echo -e "${RED}Invalid output format specified.${NC}"
            exit 1
            ;;
    esac
}

# Trap for cleanup on script exit
trap 'cleanup' EXIT INT TERM

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\n${RED}Script execution failed with exit code $exit_code${NC}"
    fi
}

# Only run main if script is being executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

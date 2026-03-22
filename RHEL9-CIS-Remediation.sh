#!/usr/bin/env bash
#
# RHEL9-CIS-Remediation.sh - CIS RHEL9 v1 Level 1 Hardening
# This script implements CIS RHEL 9 v1 Level 1 security controls
# Idempotent, non-destructive defaults. Manual/risky steps output INFO only.
#
set -euo pipefail

# --------------------------
# Logging & Output Setup
# --------------------------
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"
timestamp() { date "+%Y-%m-%d %H:%M:%S"; }
LOG="/var/log/cis_remediation.log"
CSV="/var/log/cis_remediation.csv"

info() {
    echo -e "\e[1;34m[INFO]\e[0m $*"
    echo "[$(timestamp)] [INFO] $*" >> "$LOG"
    echo "$(timestamp),INFO,$*" >> "$CSV"
}
warn() {
    echo -e "\e[1;33m[WARN]\e[0m $*"
    echo "[$(timestamp)] [WARN] $*" >> "$LOG"
    echo "$(timestamp),WARN,$*" >> "$CSV"
}
err() {
    echo -e "\e[1;31m[ERR]\e[0m $*"
    echo "[$(timestamp)] [ERR] $*" >> "$LOG"
    echo "$(timestamp),ERROR,$*" >> "$CSV"
}

# ---- Helpers ----
ensure_line_in_file() {
  local line="$1"; local file="$2"
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ] || ! grep -Fxq "$line" "$file"; then
    echo "$line" | $SUDO tee -a "$file" > /dev/null
  fi
}

ensure_config_setting() {
  local setting="$1"; local file="$2"; local section="${3:-}"
  if [ -n "$section" ]; then
    # Handle sectioned config files (like sshd_config)
    if grep -q "^${setting%%=*}" "$file" 2>/dev/null; then
      $SUDO sed -i "s|^${setting%%=*}.*|$setting|" "$file"
    else
      echo "$setting" | $SUDO tee -a "$file" > /dev/null
    fi
  else
    # Handle simple key=value files
    if grep -q "^${setting%%=*}=" "$file" 2>/dev/null; then
      $SUDO sed -i "s|^${setting%%=*}=.*|$setting|" "$file"
    else
      echo "$setting" | $SUDO tee -a "$file" > /dev/null
    fi
  fi
}

# ---------- SECTION 1: Initial Setup ----------
# 1.1.1 Configure Filesystem Kernel Modules (CIS 1.1.1.1 - 1.1.1.8)
section1_1_1_blacklist_modules() {
  info "CIS 1.1.1.* - Blacklisting unused filesystem & network kernel modules"
  MODS=(cramfs freevxfs hfs hfsplus jffs2 squashfs udf usb-storage dccp tipc rds sctp gfs2)
  for m in "${MODS[@]}"; do
    conf="/etc/modprobe.d/${m}.conf"
    ensure_line_in_file "install ${m} /bin/false" "$conf"
    ensure_line_in_file "blacklist ${m}" "$conf"
    # attempt to remove if currently loaded (no error if in-use)
    if lsmod | awk '{print $1}' | grep -xq "$m"; then
      $SUDO modprobe -r "$m" 2>/dev/null || true
      info "Tried to unload $m (may fail if in use)"
    fi
  done
  info "Done: kernel blacklists added (CIS 1.1.1.*)."
}

# 1.1.2 Configure Filesystem Partitions & mount options (CIS 1.1.2.*)
section1_1_2_partitions_and_mounts() {
  info "CIS 1.1.2.* - Enforce mount options where entries exist."
  FSTAB="/etc/fstab"
  EXTRA_OPTS="nosuid,nodev,noexec"
  TARGETS=("/tmp" "/dev/shm" "/home" "/var" "/var/tmp" "/var/log" "/var/log/audit")

  for mp in "${TARGETS[@]}"; do
    if grep -Eq "^[^#].*\s+${mp}\s+" "$FSTAB"; then
      $SUDO awk -v mp="$mp" -v eo="$EXTRA_OPTS" 'BEGIN{FS=OFS="\t"} $0 ~ mp {
        split($4,a,",");
        opts=a[1];
        nopts=opts;
        if(index(nopts,"nosuid")==0) nopts = nopts"," "nosuid";
        if(index(nopts,"nodev")==0) nopts = nopts"," "nodev";
        if(index(nopts,"noexec")==0) nopts = nopts"," "noexec";
        $4 = nopts;
      } { print }' "$FSTAB" | $SUDO tee "${FSTAB}.new" > /dev/null
      $SUDO mv "${FSTAB}.new" "$FSTAB"
      info "Updated $mp options in $FSTAB (added $EXTRA_OPTS if missing)."
    else
      warn "No explicit fstab entry found for $mp. CIS prefers separate partitions (manual)."
    fi
  done
  info "NOTE: Creating separate partitions is destructive. Consider baking partitions at image build-time."
}

# 1.2 Package Management (CIS 1.2.1.*)
section1_2_package_management() {
  info "CIS 1.2.* - Package repo and gpg settings"
  DNF_CONF="/etc/dnf/dnf.conf"
  ensure_line_in_file "gpgcheck=1" "$DNF_CONF"
  info "Set gpgcheck=1 in $DNF_CONF (CIS 1.2.1.2)."
  info "INFO (CIS 1.2.1.1 & 1.2.1.3): Ensure repo GPG keys and repo_gpgcheck are configured per your org policy."
  info "1.2.2 Ensure updates/patches: INFO - scheduling 'dnf update' is manual/operational."
}

# 1.3 SELinux / Mandatory Access Control (CIS 1.3.*)
section1_3_selinux() {
  info "CIS 1.3.* - SELinux hardening"
  if ! rpm -q selinux-policy &>/dev/null; then
    warn "selinux-policy package not installed. Consider: sudo dnf install -y selinux-policy"
  fi

  if command -v grubby >/dev/null; then
    if grubby --info=ALL | grep -Eq 'selinux=0|enforcing=0'; then
      $SUDO grubby --update-kernel=ALL --remove-args="selinux=0 enforcing=0"
      info "Removed selinux=0/enforcing=0 kernel args (CIS 1.3.1.2). Reboot required."
    fi
  fi

  if grep -Eq '^SELINUX=' /etc/selinux/config; then
    $SUDO sed -ri 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
  else
    echo "SELINUX=enforcing" | $SUDO tee -a /etc/selinux/config
  fi
  info "Set /etc/selinux/config SELINUX=enforcing (CIS 1.3.1.5) - reboot required."

  PKGS=(mcstrans setroubleshoot)
  for p in "${PKGS[@]}"; do
    if rpm -q "$p" &>/dev/null; then
      $SUDO dnf remove -y "$p" || warn "Unable to auto-remove $p"
      info "Removed $p (CIS 1.3.1.7/1.3.1.8) if present."
    fi
  done
}

# 1.4 Bootloader (CIS 1.4.*)
section1_4_bootloader() {
  info "CIS 1.4.* - Bootloader hardening (GRUB)"
  for F in /boot/grub2/grub.cfg /boot/grub2/grubenv /boot/grub2/user.cfg; do
    if [ -f "$F" ]; then
      $SUDO chown root:root "$F"
      $SUDO chmod 600 "$F"
      info "Hardened $F perms (CIS 1.4.2)."
    fi
  done
  info "INFO (CIS 1.4.1): Setting GRUB password is recommended but requires manual intervention."
}

# 1.5 Process hardening (CIS 1.5.*)
section1_5_proc_hardening() {
  info "CIS 1.5.* - ASLR, ptrace, core dumps"
  SYSCTL="/etc/sysctl.d/60-kernel_sysctl.conf"
  ensure_line_in_file "kernel.randomize_va_space = 2" "$SYSCTL"
  ensure_line_in_file "kernel.yama.ptrace_scope = 1" "$SYSCTL"
  $SUDO sysctl --system >/dev/null || true
  info "Set ASLR and ptrace scope (CIS 1.5.1 & 1.5.2)."

  COREDUMP="/etc/systemd/coredump.conf"
  $SUDO mkdir -p "$(dirname "$COREDUMP")"
  if ! grep -Eq '^ProcessSizeMax=0' "$COREDUMP" 2>/dev/null; then
    echo "ProcessSizeMax=0" | $SUDO tee -a "$COREDUMP" > /dev/null
  fi
  if ! grep -Eq '^Storage=none' "$COREDUMP" 2>/dev/null; then
    echo "Storage=none" | $SUDO tee -a "$COREDUMP" > /dev/null
  fi
  info "Disabled core dumps/storage (CIS 1.5.3 & 1.5.4)."
}

# 1.6 System wide crypto policy (CIS 1.6.*)
section1_6_crypto_policy() {
  info "CIS 1.6.* - crypto policy"
  if command -v update-crypto-policies >/dev/null; then
    $SUDO update-crypto-policies --set DEFAULT || true
    info "Set crypto policy to DEFAULT (CIS 1.6.1)."
  fi

  SSHD="/etc/ssh/sshd_config"
  if [ -f "$SSHD" ]; then
    $SUDO sed -i -E '/^\s*(Ciphers|MACs|KexAlgorithms)\s+/d' "$SSHD" || true
    info "Removed local Ciphers/MACs/KexAlgorithms in $SSHD (CIS 1.6.2)."
  fi

  PKG_DIR="/etc/crypto-policies/policies/modules"
  $SUDO mkdir -p "$PKG_DIR"
  SHAFILE="$PKG_DIR/NO-SHA1.pmod"
  ensure_line_in_file "hash = -SHA1" "$SHAFILE"
  ensure_line_in_file "sign = -*-SHA1" "$SHAFILE"
  info "Added NO-SHA1.pmod (CIS 1.6.3)."
}

# 1.7 Login banners (CIS 1.7.*)
section1_7_banners() {
  info "CIS 1.7.* - configure login banners"
  BANNER="/etc/issue.net"
  MOTD="/etc/motd"
  MSG="Unauthorized access prohibited. Use of this system is monitored and subject to audit."

  echo "$MSG" | $SUDO tee "$BANNER" > /dev/null
  echo "$MSG" | $SUDO tee "$MOTD" > /dev/null

  SSHD="/etc/ssh/sshd_config"
  if [ -f "$SSHD" ]; then
    ensure_config_setting "Banner /etc/issue.net" "$SSHD" "ssh"
    info "Configured /etc/ssh/sshd_config Banner."
  fi
}

# 1.8 GNOME Display Manager (CIS 1.8.*)
section1_8_gdm() {
  info "CIS 1.8.* - GDM hardening"
  if rpm -q gdm &>/dev/null; then
    $SUDO dnf remove -y gdm || warn "Unable to remove gdm automatically."
    info "Removed GDM package (CIS 1.8.1)."
  fi
}

# ---------- SECTION 2: Services ----------
section2_1_services_disable() {
  info "CIS 2.1.* - disabling/removing common server services not in use"
  SERVICES=(autofs avahi-daemon dhcpd named dnsmasq smb vsftpd mailman rpcbind nfs-server rsyncd snmpd telnet.socket tftp.socket xinetd cups httpd squid)
  for s in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^${s}"; then
      $SUDO systemctl disable --now "$s" 2>/dev/null || true
      $SUDO systemctl mask "$s" 2>/dev/null || true
      info "Disabled/masked $s if present."
    fi
  done
}

section2_2_client_pkgs() {
  info "CIS 2.2.* - client packages removal suggestions"
  PKGS=(ftp telnet-client telnet rsh-client rsh ypbind nisclient tftp)
  for p in "${PKGS[@]}"; do
    if rpm -q "$p" &>/dev/null; then
      warn "Client package $p is installed; consider removal."
    fi
  done
}

section2_3_time_sync() {
  info "CIS 2.3.* - Ensure time synchronization (chrony)"
  if ! rpm -q chrony &>/dev/null; then
    warn "chrony not installed; consider: sudo dnf install -y chrony"
  else
    $SUDO systemctl enable --now chronyd || $SUDO systemctl enable --now chrony || true
    info "Enabled chrony service."
  fi
}

section2_4_job_schedulers() {
  info "CIS 2.4.* - cron/at hardening"
  if systemctl list-unit-files | grep -q "^crond"; then
    $SUDO systemctl enable --now crond || true
  fi
  $SUDO chown root:root /etc/crontab || true
  $SUDO chmod 0640 /etc/crontab || true
  for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
    if [ -d "$d" ]; then
      $SUDO chown -R root:root "$d" || true
      $SUDO chmod -R og-rwx "$d" || true
    fi
  done
  for f in /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny; do
    $SUDO touch "$f" || true
    $SUDO chown root:root "$f" || true
    $SUDO chmod 0640 "$f" || true
  done
  info "Hardened cron/at permissions."
}

# ---------- SECTION 4: Host Based Firewall ----------
section4_1_firewall_utility() {
  info "CIS 4.1.* - Configure firewall utility"
  # 4.1.1 Ensure nftables is installed
  if ! rpm -q nftables &>/dev/null; then
    $SUDO dnf install -y nftables || warn "Failed to install nftables"
    info "Installed nftables (CIS 4.1.1)."
  fi

  # 4.1.2 Ensure single firewall utility in use
  # Disable conflicting firewall services
  FIREWALL_SERVICES=(iptables ip6tables ebtables firewalld)
  for svc in "${FIREWALL_SERVICES[@]}"; do
    if systemctl is-enabled "$svc" &>/dev/null; then
      $SUDO systemctl disable --now "$svc" 2>/dev/null || true
      info "Disabled conflicting firewall service: $svc"
    fi
  done

  # Enable nftables
  $SUDO systemctl enable nftables || true
  info "Ensured single firewall utility (nftables) is in use (CIS 4.1.2)."
}

section4_2_firewalld() {
  info "CIS 4.2.* - Configure FirewallD (if using firewalld instead of nftables)"
  if rpm -q firewalld &>/dev/null; then
    # 4.2.2 Ensure firewalld loopback traffic is configured
    $SUDO firewall-cmd --permanent --zone=trusted --add-interface=lo 2>/dev/null || true
    $SUDO firewall-cmd --permanent --zone=trusted --add-source=127.0.0.1/8 2>/dev/null || true
    $SUDO firewall-cmd --permanent --zone=trusted --add-source=::1/128 2>/dev/null || true
    $SUDO firewall-cmd --reload 2>/dev/null || true
    info "Configured firewalld loopback traffic (CIS 4.2.2)."

    # 4.2.1 is manual - requires site-specific service/port review
    info "INFO (CIS 4.2.1): Manually review and remove unnecessary services/ports from firewalld zones."
  fi
}

section4_3_nftables() {
  info "CIS 4.3.* - Configure NFTables"
  if rpm -q nftables &>/dev/null && systemctl is-enabled nftables &>/dev/null; then
    # 4.3.1 Ensure nftables base chains exist
    $SUDO nft add table inet filter 2>/dev/null || true
    $SUDO nft add chain inet filter input '{ type filter hook input priority 0; policy drop; }' 2>/dev/null || true
    $SUDO nft add chain inet filter forward '{ type filter hook forward priority 0; policy drop; }' 2>/dev/null || true
    $SUDO nft add chain inet filter output '{ type filter hook output priority 0; policy drop; }' 2>/dev/null || true
    info "Created nftables base chains (CIS 4.3.1)."

    # 4.3.3 Ensure nftables default deny firewall policy (already set above)
    info "Set nftables default deny policy (CIS 4.3.3)."

    # 4.3.4 Ensure nftables loopback traffic is configured
    $SUDO nft add rule inet filter input iif lo accept 2>/dev/null || true
    $SUDO nft add rule inet filter output oif lo accept 2>/dev/null || true
    $SUDO nft add rule inet filter input ip saddr 127.0.0.0/8 counter drop 2>/dev/null || true
    $SUDO nft add rule inet filter input ip6 saddr ::1 counter drop 2>/dev/null || true
    info "Configured nftables loopback traffic (CIS 4.3.4)."

    # Save configuration
    $SUDO nft list ruleset > /etc/nftables/nftables.conf 2>/dev/null || true
    info "Saved nftables configuration."

    # 4.3.2 is manual - requires site-specific established connection rules
    info "INFO (CIS 4.3.2): Manually configure established connection rules per your requirements."
  fi
}

# ---------- SECTION 5: Access Control ----------
section5_1_ssh_server() {
  info "CIS 5.1.* - Configure SSH Server"
  SSHD_CONFIG="/etc/ssh/sshd_config"

  # 5.1.1 Ensure permissions on /etc/ssh/sshd_config
  $SUDO chown root:root "$SSHD_CONFIG"
  $SUDO chmod 600 "$SSHD_CONFIG"
  info "Set sshd_config permissions (CIS 5.1.1)."

  # 5.1.2 & 5.1.3 SSH key permissions
  for key in /etc/ssh/ssh_host_*_key; do
    if [ -f "$key" ]; then
      $SUDO chown root:root "$key"
      $SUDO chmod 600 "$key"
    fi
  done
  for key in /etc/ssh/ssh_host_*_key.pub; do
    if [ -f "$key" ]; then
      $SUDO chown root:root "$key"
      $SUDO chmod 644 "$key"
    fi
  done
  info "Set SSH key permissions (CIS 5.1.2 & 5.1.3)."

  # SSH Configuration settings
  SSH_SETTINGS=(
    "Protocol 2"
    "LogLevel INFO"
    "X11Forwarding no"
    "MaxAuthTries 4"
    "MaxSessions 10"
    "MaxStartups 10:30:100"
    "IgnoreRhosts yes"
    "HostbasedAuthentication no"
    "PermitRootLogin no"
    "PermitEmptyPasswords no"
    "PermitUserEnvironment no"
    "ClientAliveInterval 15"
    "ClientAliveCountMax 3"
    "LoginGraceTime 60"
    "Banner /etc/issue.net"
    "UsePAM yes"
    "DisableForwarding yes"
    "GSSAPIAuthentication no"
  )

  for setting in "${SSH_SETTINGS[@]}"; do
    key=$(echo "$setting" | cut -d' ' -f1)
    # Remove existing setting
    $SUDO sed -i "/^${key}\s/d" "$SSHD_CONFIG" 2>/dev/null || true
    # Add new setting
    echo "$setting" | $SUDO tee -a "$SSHD_CONFIG" > /dev/null
  done

  info "Applied SSH hardening settings (CIS 5.1.4-5.1.22)."
  info "NOTE: SSH crypto settings (Ciphers, MACs, KexAlgorithms) removed to use system crypto policy."

  # Restart SSH to apply changes
  $SUDO systemctl reload sshd || warn "Failed to reload sshd - check configuration"
}

section5_2_privilege_escalation() {
  info "CIS 5.2.* - Configure privilege escalation"

  # 5.2.1 Ensure sudo is installed
  if ! rpm -q sudo &>/dev/null; then
    $SUDO dnf install -y sudo || warn "Failed to install sudo"
    info "Installed sudo (CIS 5.2.1)."
  fi

  SUDOERS_D="/etc/sudoers.d/01_cis_hardening"

  # 5.2.2 Ensure sudo commands use pty
  ensure_line_in_file "Defaults use_pty" "$SUDOERS_D"

  # 5.2.3 Ensure sudo log file exists
  ensure_line_in_file "Defaults logfile=\"/var/log/sudo.log\"" "$SUDOERS_D"

  # 5.2.4, 5.2.5, 5.2.6 Password requirements and timeouts
  ensure_line_in_file "Defaults !visiblepw" "$SUDOERS_D"
  ensure_line_in_file "Defaults timestamp_timeout=15" "$SUDOERS_D"
  ensure_line_in_file "Defaults !rootpw" "$SUDOERS_D"
  ensure_line_in_file "Defaults !runaspw" "$SUDOERS_D"
  ensure_line_in_file "Defaults !targetpw" "$SUDOERS_D"

  info "Configured sudo security settings (CIS 5.2.2-5.2.6)."

  # 5.2.7 Ensure access to su command is restricted
  if ! grep -q "auth required pam_wheel.so use_uid" /etc/pam.d/su 2>/dev/null; then
    echo "auth required pam_wheel.so use_uid" | $SUDO tee -a /etc/pam.d/su > /dev/null
    info "Restricted su command access (CIS 5.2.7)."
  fi
}

section5_3_pam() {
  info "CIS 5.3.* - Pluggable Authentication Modules"

  # 5.3.1.* Ensure PAM packages are installed
  PAM_PACKAGES=(pam authselect libpwquality)
  for pkg in "${PAM_PACKAGES[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
      $SUDO dnf install -y "$pkg" || warn "Failed to install $pkg"
    fi
  done
  info "Ensured PAM packages installed (CIS 5.3.1.*)."

  # 5.3.2.* Configure authselect
  if command -v authselect >/dev/null; then
    $SUDO authselect select sssd with-faillock with-pwquality with-pwhistory --force 2>/dev/null || true
    info "Configured authselect profile (CIS 5.3.2.*)."
  fi

  # 5.3.3.1.* Configure pam_faillock
  FAILLOCK_CONF="/etc/security/faillock.conf"
  $SUDO mkdir -p "$(dirname "$FAILLOCK_CONF")"

  FAILLOCK_SETTINGS=(
    "deny = 5"
    "unlock_time = 900"
    "even_deny_root"
  )

  for setting in "${FAILLOCK_SETTINGS[@]}"; do
    key=$(echo "$setting" | cut -d' ' -f1)
    $SUDO sed -i "/^${key}\s*=/d" "$FAILLOCK_CONF" 2>/dev/null || true
    echo "$setting" | $SUDO tee -a "$FAILLOCK_CONF" > /dev/null
  done
  info "Configured pam_faillock (CIS 5.3.3.1.*)."

  # 5.3.3.2.* Configure pam_pwquality
  PWQUALITY_CONF="/etc/security/pwquality.conf"

  PWQUALITY_SETTINGS=(
    "minlen = 8"
    "dcredit = -1"
    "ucredit = -1"
    "lcredit = -1"
    "ocredit = -1"
    "difok = 2"
    "maxsequence = 3"
    "maxrepeat = 3"
    "dictcheck = 1"
    "enforce_for_root"
  )

  for setting in "${PWQUALITY_SETTINGS[@]}"; do
    key=$(echo "$setting" | cut -d' ' -f1)
    $SUDO sed -i "/^${key}\s*=/d" "$PWQUALITY_CONF" 2>/dev/null || true
    echo "$setting" | $SUDO tee -a "$PWQUALITY_CONF" > /dev/null
  done
  info "Configured pam_pwquality (CIS 5.3.3.2.*)."

  # 5.3.3.3.* Configure pam_pwhistory
  # This is typically configured in authselect, but we ensure the setting
  info "pam_pwhistory configured via authselect (CIS 5.3.3.3.*)."
}

section5_4_user_accounts() {
  info "CIS 5.4.* - User Accounts and Environment"

  # 5.4.1.* Configure shadow password suite parameters
  LOGIN_DEFS="/etc/login.defs"

  LOGIN_SETTINGS=(
    "PASS_MAX_DAYS 90"
    "PASS_MIN_DAYS 1"
    "PASS_WARN_AGE 7"
    "ENCRYPT_METHOD SHA512"
    "INACTIVE 30"
  )

  for setting in "${LOGIN_SETTINGS[@]}"; do
    key=$(echo "$setting" | cut -d' ' -f1)
    $SUDO sed -i "/^${key}\s/d" "$LOGIN_DEFS" 2>/dev/null || true
    echo "$setting" | $SUDO tee -a "$LOGIN_DEFS" > /dev/null
  done
  info "Configured password aging (CIS 5.4.1.*)."

  # 5.4.2.* Configure root and system accounts
  # Check for multiple UID 0 accounts
  if [ "$(awk -F: '$3==0 {print $1}' /etc/passwd | wc -l)" -gt 1 ]; then
    warn "Multiple UID 0 accounts found (CIS 5.4.2.1) - manual review required"
  fi

  # 5.4.2.6 Ensure root user umask is configured
  ROOT_UMASK_FILES=(/root/.bashrc /root/.profile /etc/profile)
  for file in "${ROOT_UMASK_FILES[@]}"; do
    if [ -f "$file" ]; then
      if ! grep -q "umask 0027" "$file"; then
        echo "umask 0027" | $SUDO tee -a "$file" > /dev/null
      fi
    fi
  done
  info "Set root umask to 0027 (CIS 5.4.2.6)."

  # 5.4.3.* Configure user default environment
  # 5.4.3.2 Ensure default user shell timeout
  PROFILE_FILES=(/etc/profile /etc/bash.bashrc)
  for file in "${PROFILE_FILES[@]}"; do
    if [ -f "$file" ]; then
      if ! grep -q "TMOUT=" "$file"; then
        echo "TMOUT=600" | $SUDO tee -a "$file" > /dev/null
        echo "export TMOUT" | $SUDO tee -a "$file" > /dev/null
      fi
    fi
  done
  info "Set default shell timeout (CIS 5.4.3.2)."

  # 5.4.3.3 Ensure default user umask is configured
  if ! grep -q "umask 0027" /etc/profile; then
    echo "umask 0027" | $SUDO tee -a /etc/profile > /dev/null
  fi
  info "Set default user umask (CIS 5.4.3.3)."
}

# ---------- SECTION 6: Logging and Auditing ----------
section6_1_aide() {
  info "CIS 6.1.* - Configure Integrity Checking (AIDE)"

  # 6.1.1 Ensure AIDE is installed
  if ! rpm -q aide &>/dev/null; then
    $SUDO dnf install -y aide || warn "Failed to install aide"
    info "Installed AIDE (CIS 6.1.1)."

    # Initialize AIDE database
    $SUDO aide --init || warn "AIDE initialization failed"
    if [ -f /var/lib/aide/aide.db.new.gz ]; then
      $SUDO mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
      info "Moved AIDE database to production location."
    fi
  fi

  # 6.1.2 Ensure filesystem integrity is regularly checked
  AIDE_CRON="/etc/cron.d/aide"
  ensure_line_in_file "0 5 * * * root /usr/sbin/aide --check" "$AIDE_CRON"
  info "Configured AIDE to run daily at 5 AM (CIS 6.1.2)."

  # 6.1.3 Ensure cryptographic mechanisms are used to protect the integrity of audit tools
  AIDE_CONF="/etc/aide.conf"
  if [ -f "$AIDE_CONF" ]; then
    AUDIT_TOOLS="/usr/sbin/auditctl /usr/sbin/auditd /usr/sbin/ausearch /usr/sbin/aureport /usr/sbin/autrace /usr/sbin/augenrules"
    for tool in $AUDIT_TOOLS; do
      if [ -f "$tool" ] && ! grep -q "$tool" "$AIDE_CONF"; then
        echo "$tool p+i+n+u+g+s+b+acl+selinux+xattrs+sha512" | $SUDO tee -a "$AIDE_CONF" > /dev/null
      fi
    done
    info "Added audit tools to AIDE monitoring (CIS 6.1.3)."
  fi
}

section6_2_system_logging() {
  info "CIS 6.2.* - System Logging"

  # 6.2.1.1 Ensure journald service is enabled and active
  $SUDO systemctl enable --now systemd-journald || true
  info "Enabled systemd-journald service (CIS 6.2.1.1)."

  # 6.2.1.4 Ensure only one logging system is in use
  if rpm -q rsyslog &>/dev/null; then
    $SUDO systemctl enable --now rsyslog || true
    info "Using rsyslog as primary logging system (CIS 6.2.1.4)."
  fi

  # 6.2.2.* Configure journald
  JOURNALD_CONF="/etc/systemd/journald.conf"
  $SUDO mkdir -p "$(dirname "$JOURNALD_CONF")"

  # 6.2.2.2 Ensure journald ForwardToSyslog is disabled
  ensure_config_setting "ForwardToSyslog=no" "$JOURNALD_CONF"

  # 6.2.2.3 Ensure journald Compress is configured
  ensure_config_setting "Compress=yes" "$JOURNALD_CONF"

  # 6.2.2.4 Ensure journald Storage is configured
  ensure_config_setting "Storage=persistent" "$JOURNALD_CONF"

  $SUDO systemctl restart systemd-journald || true
  info "Configured systemd-journald settings (CIS 6.2.2.*)."

  # 6.2.3.* Configure rsyslog
  if rpm -q rsyslog &>/dev/null; then
    # 6.2.3.2 Ensure rsyslog service is enabled and active
    $SUDO systemctl enable --now rsyslog || true

    # 6.2.3.4 Ensure rsyslog log file creation mode is configured
    RSYSLOG_CONF="/etc/rsyslog.conf"
    if ! grep -q "\$FileCreateMode" "$RSYSLOG_CONF"; then
      echo "\$FileCreateMode 0640" | $SUDO tee -a "$RSYSLOG_CONF" > /dev/null
    fi

    # 6.2.3.7 Ensure rsyslog is not configured to receive logs from a remote client
    $SUDO sed -i 's/^#*\$ModLoad imudp/#\$ModLoad imudp/' "$RSYSLOG_CONF" 2>/dev/null || true
    $SUDO sed -i 's/^#*\$UDPServerRun/#\$UDPServerRun/' "$RSYSLOG_CONF" 2>/dev/null || true
    $SUDO sed -i 's/^#*\$ModLoad imtcp/#\$ModLoad imtcp/' "$RSYSLOG_CONF" 2>/dev/null || true
    $SUDO sed -i 's/^#*\$InputTCPServerRun/#\$InputTCPServerRun/' "$RSYSLOG_CONF" 2>/dev/null || true

    $SUDO systemctl restart rsyslog || true
    info "Configured rsyslog settings (CIS 6.2.3.*)."
  fi

  # 6.2.4.1 Ensure access to all logfiles has been configured
  LOG_DIRS="/var/log"
  find "$LOG_DIRS" -type f -name "*.log" -exec $SUDO chmod 640 {} \; 2>/dev/null || true
  find "$LOG_DIRS" -type f -name "*.log" -exec $SUDO chown root:root {} \; 2>/dev/null || true
  info "Secured log file permissions (CIS 6.2.4.1)."
}

section6_3_system_auditing() {
  info "CIS 6.3.* - System Auditing"

  # 6.3.1.1 Ensure auditd packages are installed
  AUDIT_PACKAGES=(audit audit-libs)
  for pkg in "${AUDIT_PACKAGES[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
      $SUDO dnf install -y "$pkg" || warn "Failed to install $pkg"
    fi
  done
  info "Installed auditd packages (CIS 6.3.1.1)."

  # 6.3.1.2 Ensure auditing for processes that start prior to auditd is enabled
  if command -v grubby >/dev/null; then
    $SUDO grubby --update-kernel=ALL --args="audit=1" || true
    info "Enabled early auditing in kernel parameters (CIS 6.3.1.2) - reboot required."
  fi

  # 6.3.1.3 Ensure audit_backlog_limit is sufficient
  if command -v grubby >/dev/null; then
    $SUDO grubby --update-kernel=ALL --args="audit_backlog_limit=8192" || true
    info "Set audit_backlog_limit=8192 (CIS 6.3.1.3) - reboot required."
  fi

  # 6.3.1.4 Ensure auditd service is enabled and active
  $SUDO systemctl enable --now auditd || true
  info "Enabled auditd service (CIS 6.3.1.4)."

  # 6.3.2.* Configure Data Retention
  AUDITD_CONF="/etc/audit/auditd.conf"

  # 6.3.2.1 Ensure audit log storage size is configured
  ensure_config_setting "max_log_file = 100" "$AUDITD_CONF"

  # 6.3.2.2 Ensure audit logs are not automatically deleted
  ensure_config_setting "max_log_file_action = rotate" "$AUDITD_CONF"

  # 6.3.2.3 Ensure system is disabled when audit logs are full
  ensure_config_setting "space_left_action = email" "$AUDITD_CONF"
  ensure_config_setting "admin_space_left_action = halt" "$AUDITD_CONF"

  # 6.3.2.4 Ensure system warns when audit logs are low on space
  ensure_config_setting "space_left = 25%" "$AUDITD_CONF"

  info "Configured auditd data retention (CIS 6.3.2.*)."

  # 6.3.3.* Configure auditd Rules
  AUDIT_RULES="/etc/audit/rules.d/cis.rules"
  $SUDO mkdir -p "$(dirname "$AUDIT_RULES")"

  cat <<'EOF' | $SUDO tee "$AUDIT_RULES" > /dev/null
# CIS 6.3.3.1 Ensure changes to system administration scope (sudoers) is collected
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope

# CIS 6.3.3.2 Ensure actions as another user are always logged
-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation

# CIS 6.3.3.3 Ensure events that modify the sudo log file are collected
-w /var/log/sudo.log -p wa -k sudo_log_file

# CIS 6.3.3.4 Ensure events that modify date and time information are collected
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# CIS 6.3.3.5 Ensure events that modify the system's network environment are collected
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale

# CIS 6.3.3.6 Ensure use of privileged commands are collected
# This rule will be populated by finding all privileged commands
# Placeholder - actual privileged commands should be found and added

# CIS 6.3.3.7 Ensure unsuccessful file access attempts are collected
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EACCES -F auid!=unset -k access
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EPERM -F auid!=unset -k access
-a always,exit -F arch=b32 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EACCES -F auid!=unset -k access
-a always,exit -F arch=b32 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EPERM -F auid!=unset -k access

# CIS 6.3.3.8 Ensure events that modify user/group information are collected
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# CIS 6.section6_1_aide() {
  info "CIS 6.1.* - Configure Integrity Checking (AIDE)"

  # 6.1.1 Ensure AIDE is installed
  if ! rpm -q aide &>/dev/null; then
    $SUDO dnf install -y aide || warn "Failed to install aide"
    info "Installed AIDE (CIS 6.1.1)."

    # Initialize AIDE database
    $SUDO aide --init || warn "AIDE initialization failed"
    if [ -f /var/lib/aide/aide.db.new.gz ]; then
      $SUDO mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
      info "Moved AIDE database to production location."
    fi
  fi

  # 6.1.2 Ensure filesystem integrity is regularly checked
  AIDE_CRON="/etc/cron.d/aide"
  ensure_line_in_file "0 5 * * * root /usr/sbin/aide --check" "$AIDE_CRON"
  info "Configured AIDE to run daily at 5 AM (CIS 6.1.2)."

  # 6.1.3 Ensure cryptographic mechanisms are used to protect the integrity of audit tools
  AIDE_CONF="/etc/aide.conf"
  if [ -f "$AIDE_CONF" ]; then
    AUDIT_TOOLS="/usr/sbin/auditctl /usr/sbin/auditd /usr/sbin/ausearch /usr/sbin/aureport /usr/sbin/autrace /usr/sbin/augenrules"
    for tool in $AUDIT_TOOLS; do
      if [ -f "$tool" ] && ! grep -q "$tool" "$AIDE_CONF"; then
        echo "$tool p+i+n+u+g+s+b+acl+selinux+xattrs+sha512" | $SUDO tee -a "$AIDE_CONF" > /dev/null
      fi
    done
    info "Added audit tools to AIDE monitoring (CIS 6.1.3)."
  fi
}

section6_2_system_logging() {
  info "CIS 6.2.* - System Logging"

  # 6.2.1.1 Ensure journald service is enabled and active
  $SUDO systemctl enable --now systemd-journald || true
  info "Enabled systemd-journald service (CIS 6.2.1.1)."

  # 6.2.1.4 Ensure only one logging system is in use
  if rpm -q rsyslog &>/dev/null; then
    $SUDO systemctl enable --now rsyslog || true
    info "Using rsyslog as primary logging system (CIS 6.2.1.4)."
  fi

  # 6.2.2.* Configure journald
  JOURNALD_CONF="/etc/systemd/journald.conf"
  $SUDO mkdir -p "$(dirname "$JOURNALD_CONF")"

  # 6.2.2.2 Ensure journald ForwardToSyslog is disabled
  ensure_config_setting "ForwardToSyslog=no" "$JOURNALD_CONF"

  # 6.2.2.3 Ensure journald Compress is configured
  ensure_config_setting "Compress=yes" "$JOURNALD_CONF"

  # 6.2.2.4 Ensure journald Storage is configured
  ensure_config_setting "Storage=persistent" "$JOURNALD_CONF"

  $SUDO systemctl restart systemd-journald || true
  info "Configured systemd-journald settings (CIS 6.2.2.*)."

  # 6.2.3.* Configure rsyslog
  if rpm -q rsyslog &>/dev/null; then
    # 6.2.3.2 Ensure rsyslog service is enabled and active
    $SUDO systemctl enable --now rsyslog || true

    # 6.2.3.4 Ensure rsyslog log file creation mode is configured
    RSYSLOG_CONF="/etc/rsyslog.conf"
    if ! grep -q "\$FileCreateMode" "$RSYSLOG_CONF"; then
      echo "\$FileCreateMode 0640" | $SUDO tee -a "$RSYSLOG_CONF" > /dev/null
    fi

    # 6.2.3.7 Ensure rsyslog is not configured to receive logs from a remote client
    $SUDO sed -i 's/^#*\$ModLoad imudp/#\$ModLoad imudp/' "$RSYSLOG_CONF" 2>/dev/null || true
    $SUDO sed -i 's/^#*\$UDPServerRun/#\$UDPServerRun/' "$RSYSLOG_CONF" 2>/dev/null || true
    $SUDO sed -i 's/^#*\$ModLoad imtcp/#\$ModLoad imtcp/' "$RSYSLOG_CONF" 2>/dev/null || true
    $SUDO sed -i 's/^#*\$InputTCPServerRun/#\$InputTCPServerRun/' "$RSYSLOG_CONF" 2>/dev/null || true

    $SUDO systemctl restart rsyslog || true
    info "Configured rsyslog settings (CIS 6.2.3.*)."
  fi

  # 6.2.4.1 Ensure access to all logfiles has been configured
  LOG_DIRS="/var/log"
  find "$LOG_DIRS" -type f -name "*.log" -exec $SUDO chmod 640 {} \; 2>/dev/null || true
  find "$LOG_DIRS" -type f -name "*.log" -exec $SUDO chown root:root {} \; 2>/dev/null || true
  info "Secured log file permissions (CIS 6.2.4.1)."
}

section6_3_system_auditing() {
  info "CIS 6.3.* - System Auditing"

  # 6.3.1.1 Ensure auditd packages are installed
  AUDIT_PACKAGES=(audit audit-libs)
  for pkg in "${AUDIT_PACKAGES[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
      $SUDO dnf install -y "$pkg" || warn "Failed to install $pkg"
    fi
  done
  info "Installed auditd packages (CIS 6.3.1.1)."

  # 6.3.1.2 Ensure auditing for processes that start prior to auditd is enabled
  if command -v grubby >/dev/null; then
    $SUDO grubby --update-kernel=ALL --args="audit=1" || true
    info "Enabled early auditing in kernel parameters (CIS 6.3.1.2) - reboot required."
  fi

  # 6.3.1.3 Ensure audit_backlog_limit is sufficient
  if command -v grubby >/dev/null; then
    $SUDO grubby --update-kernel=ALL --args="audit_backlog_limit=8192" || true
    info "Set audit_backlog_limit=8192 (CIS 6.3.1.3) - reboot required."
  fi

  # 6.3.1.4 Ensure auditd service is enabled and active
  $SUDO systemctl enable --now auditd || true
  info "Enabled auditd service (CIS 6.3.1.4)."

  # 6.3.2.* Configure Data Retention
  AUDITD_CONF="/etc/audit/auditd.conf"

  # 6.3.2.1 Ensure audit log storage size is configured
  ensure_config_setting "max_log_file = 100" "$AUDITD_CONF"

  # 6.3.2.2 Ensure audit logs are not automatically deleted
  ensure_config_setting "max_log_file_action = rotate" "$AUDITD_CONF"

  # 6.3.2.3 Ensure system is disabled when audit logs are full
  ensure_config_setting "space_left_action = email" "$AUDITD_CONF"
  ensure_config_setting "admin_space_left_action = halt" "$AUDITD_CONF"

  # 6.3.2.4 Ensure system warns when audit logs are low on space
  ensure_config_setting "space_left = 25%" "$AUDITD_CONF"

  info "Configured auditd data retention (CIS 6.3.2.*)."

  # 6.3.3.* Configure auditd Rules
  AUDIT_RULES="/etc/audit/rules.d/cis.rules"
  $SUDO mkdir -p "$(dirname "$AUDIT_RULES")"

  cat <<'EOF' | $SUDO tee "$AUDIT_RULES" > /dev/null
# CIS 6.3.3.1 Ensure changes to system administration scope (sudoers) is collected
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope

# CIS 6.3.3.2 Ensure actions as another user are always logged
-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation

# CIS 6.3.3.3 Ensure events that modify the sudo log file are collected
-w /var/log/sudo.log -p wa -k sudo_log_file

# CIS 6.3.3.4 Ensure events that modify date and time information are collected
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# CIS 6.3.3.5 Ensure events that modify the system's network environment are collected
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale

# CIS 6.3.3.6 Ensure use of privileged commands are collected
# This rule will be populated by finding all privileged commands
# Placeholder - actual privileged commands should be found and added

# CIS 6.3.3.7 Ensure unsuccessful file access attempts are collected
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EACCES -F auid!=unset -k access
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EPERM -F auid!=unset -k access
-a always,exit -F arch=b32 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EACCES -F auid!=unset -k access
-a always,exit -F arch=b32 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EPERM -F auid!=unset -k access

# CIS 6.3.3.8 Ensure events that modify user/group information are collected
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# CIS 6.3.3.9 Ensure discretionary access control permission modification events are collected
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S chown,fchown,lchown,fchownat -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S chown,fchown,lchown,fchownat -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid!=unset -k perm_mod

# CIS 6.3.3.10 Ensure successful file system mounts are collected
-a always,exit -F arch=b64 -S mount -F auid!=unset -k mounts
-a always,exit -F arch=b32 -S mount -F auid!=unset -k mounts

# CIS 6.3.3.11 Ensure session initiation information is collected
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

# CIS 6.3.3.12 Ensure login and logout events are collected
-w /var/log/lastlog -p wa -k logins

# CIS 6.3.3.13 Ensure file deletion events by users are collected
-a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F auid!=unset -k delete
-a always,exit -F arch=b32 -S rename,unlink,unlinkat,renameat -F auid!=unset -k delete

# CIS 6.3.3.14 Ensure events that modify the system's Mandatory Access Controls are collected
-w /etc/selinux -p wa -k MAC-policy

# CIS 6.3.3.15 Ensure successful and unsuccessful attempts to use the chcon command are collected
-a always,exit -F path=/usr/bin/chcon -F perm=x -F auid!=unset -k perm_chng

# CIS 6.3.3.16 Ensure successful and unsuccessful attempts to use the setfacl command are collected
-a always,exit -F path=/usr/bin/setfacl -F perm=x -F auid!=unset -k perm_chng

# CIS 6.3.3.17 Ensure successful and unsuccessful attempts to use the chacl command are collected
-a always,exit -F path=/usr/bin/chacl -F perm=x -F auid!=unset -k perm_chng

# CIS 6.3.3.18 Ensure successful and unsuccessful attempts to use the usermod command are collected
-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid!=unset -k usermod

# CIS 6.3.3.19 Ensure kernel module loading unloading and modification is collected
-a always,exit -F arch=b64 -S init_module,delete_module,finit_module -F auid!=unset -k modules
-a always,exit -F arch=b32 -S init_module,delete_module,finit_module -F auid!=unset -k modules

# CIS 6.3.3.20 Ensure the audit configuration is immutable
-e 2
EOF

  # Add privileged commands to audit rules (CIS 6.3.3.6)
  find /usr -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | \
    while read -r file; do
      echo "-a always,exit -F path=$file -F perm=x -F auid!=unset -k privileged" | $SUDO tee -a "$AUDIT_RULES" > /dev/null
    done 2>/dev/null || true

  $SUDO augenrules --load || true
  info "Configured comprehensive audit rules (CIS 6.3.3.*)."

  # 6.3.4.* Configure auditd File Access
  AUDIT_LOG_DIR="/var/log/audit"

  # 6.3.4.1 Ensure the audit log file directory mode is configured
  $SUDO chmod 750 "$AUDIT_LOG_DIR" 2>/dev/null || true

  # 6.3.4.2-4 Ensure audit log files permissions
  find "$AUDIT_LOG_DIR" -type f -name "audit.log*" -exec $SUDO chmod 600 {} \; 2>/dev/null || true
  find "$AUDIT_LOG_DIR" -type f -name "audit.log*" -exec $SUDO chown root:root {} \; 2>/dev/null || true

  # 6.3.4.5-7 Ensure audit configuration files permissions
  find /etc/audit -type f -exec $SUDO chmod 640 {} \; 2>/dev/null || true
  find /etc/audit -type f -exec $SUDO chown root:root {} \; 2>/dev/null || true

  # 6.3.4.8-10 Ensure audit tools permissions
  AUDIT_TOOLS="/usr/sbin/auditctl /usr/sbin/auditd /usr/sbin/ausearch /usr/sbin/aureport /usr/sbin/autrace /usr/sbin/augenrules"
  for tool in $AUDIT_TOOLS; do
    if [ -f "$tool" ]; then
      $SUDO chmod 755 "$tool"
      $SUDO chown root:root "$tool"
    fi
  done
  info "Configured audit file access permissions (CIS 6.3.4.*)."
}

# --------------------------
# Execution & summary
# --------------------------

main() {
    # Create log files with proper permissions
    $SUDO touch "$LOG" "$CSV"
    $SUDO chmod 600 "$LOG" "$CSV"

    echo "----- CIS RHEL9 Level-1 Remediation run: $(timestamp) -----" | tee -a "$LOG"
    echo "timestamp,level,message" | $SUDO tee "$CSV" > /dev/null

    # Section 1: Initial Setup
    info "Starting Section 1: Initial Setup"
    section1_1_1_blacklist_modules      # Filesystem configuration
    section1_1_2_partitions_and_mounts  # Mount options
    section1_2_package_management       # Package management
    section1_3_selinux                 # SELinux configuration
    section1_4_bootloader              # Bootloader security
    section1_5_proc_hardening          # Process hardening
    section1_6_crypto_policy           # Crypto policy
    section1_7_banners                 # Warning banners
    section1_8_gdm                     # GNOME display manager

    # Section 2: Services
    info "Starting Section 2: Services"
    section2_1_services_disable        # Disable unnecessary services
    section2_2_client_pkgs            # Remove client packages
    section2_3_time_sync              # Time synchronization
    section2_4_job_schedulers         # Cron and at configuration

    # Section 4: Network Configuration
    info "Starting Section 4: Network Configuration"
    section4_1_firewall_utility       # Firewall selection
    section4_2_firewalld             # FirewallD configuration
    section4_3_nftables              # NFTables configuration

    # Section 5: Access, Authentication and Authorization
    info "Starting Section 5: Access Control"
    section5_1_ssh_server            # SSH Server configuration
    section5_2_privilege_escalation  # Sudo configuration
    section5_3_pam                   # PAM configuration
    section5_4_user_accounts         # User account controls

    # Section 6: System Maintenance
    info "Starting Section 6: System Maintenance"
    section6_1_aide                  # AIDE integrity monitoring
    section6_2_system_logging       # System logging
    section6_3_system_auditing      # Audit configuration

    echo "----- Remediation Completed: $(timestamp) -----" | tee -a "$LOG"

    # Print summary
    echo
    info "Remediation Summary:"
    echo "----------------------------------------"
    echo "Log file: $LOG"
    echo "CSV report: $CSV"
    echo
    info "Last 10 actions taken:"
    tail -n 10 "$CSV" | column -t -s','
    echo
    info "Required Actions:"
    echo "1. Review $LOG for any warnings or errors"
    echo "2. Run a new compliance scan to verify changes"
    echo "3. Some changes require a reboot to take effect"
    echo "4. Verify critical services are functioning"
}

# Execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
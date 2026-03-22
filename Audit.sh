
#!/bin/bash

MODPROBE_DIR="/etc/modprobe.d"
TARGET_FILE="$MODPROBE_DIR/squashfs.conf"
SOURCE_FILE="$MODPROBE_DIR/squashfs.config"

if [ -f "$TARGET_FILE" ]; then
    echo "File '$TARGET_FILE' already exists. Skipping."
elif [ -f "$SOURCE_FILE" ]; then
    mv -v "$SOURCE_FILE" "$TARGET_FILE"
    echo "Renamed '$SOURCE_FILE' to '$TARGET_FILE'."
else
    echo "'$TARGET_FILE' not found. Creating it with default squashfs block."
    cat << EOF > "$TARGET_FILE"
install squashfs /bin/false
blacklist squashfs
EOF
    echo "Created '$TARGET_FILE'."
fi

#!/bin/bash

CONF_FILE="/etc/modprobe.d/cramfs.conf"
INSTALL_LINE="install cramfs /bin/false"
BLACKLIST_LINE="blacklist cramfs"
UPDATED=0

# Create file if it doesn't exist but only when necessary
if [ ! -f "$CONF_FILE" ]; then
    touch "$CONF_FILE"
fi

# Add 'install' line if missing
if ! grep -Fxq "$INSTALL_LINE" "$CONF_FILE"; then
    echo "$INSTALL_LINE" >> "$CONF_FILE"
    echo "Added: $INSTALL_LINE"
    UPDATED=1
fi

# Add 'blacklist' line if missing
if ! grep -Fxq "$BLACKLIST_LINE" "$CONF_FILE"; then
    echo "$BLACKLIST_LINE" >> "$CONF_FILE"
    echo "Added: $BLACKLIST_LINE"
    UPDATED=1
fi

# Status message
if [ "$UPDATED" -eq 0 ]; then
    echo "$CONF_FILE already contains required settings. Skipping."
else
    echo "Updated $CONF_FILE:"
    cat "$CONF_FILE"
fi


#!/bin/bash

# 1.1.1.8 Ensure usb-storage kernel module is not available

FILE_PATH="/etc/modprobe.d/usb-storage.conf"
touch "$FILE_PATH"

# Check and add 'install usb-storage /bin/false' if missing
if ! grep -Fxq "install usb-storage /bin/false" "$FILE_PATH"; then
    echo "install usb-storage /bin/false" >> "$FILE_PATH"
    echo "Added: install usb-storage /bin/false"
else
    echo "Line already exists: install usb-storage /bin/false"
fi

# Check and add 'blacklist usb-storage' if missing
if ! grep -Fxq "blacklist usb-storage" "$FILE_PATH"; then
    echo "blacklist usb-storage" >> "$FILE_PATH"
    echo "Added: blacklist usb-storage"
else
    echo "Line already exists: blacklist usb-storage"
fi

# Display the result
echo "Current content of $FILE_PATH:"
cat "$FILE_PATH"

#!/bin/bash

# 1.1.1.7 Ensure udf kernel module is not available

FILE_PATH="/etc/modprobe.d/udf.conf"
touch "$FILE_PATH"

# Add 'install udf /bin/false' if not already present
if ! grep -Fxq "install udf /bin/false" "$FILE_PATH"; then
    echo "install udf /bin/false" >> "$FILE_PATH"
    echo "Added: install udf /bin/false"
else
    echo "Line already exists: install udf /bin/false"
fi

# Add 'blacklist udf' if not already present
if ! grep -Fxq "blacklist udf" "$FILE_PATH"; then
    echo "blacklist udf" >> "$FILE_PATH"
    echo "Added: blacklist udf"
else
    echo "Line already exists: blacklist udf"
fi

# Show final content
echo "Current content of $FILE_PATH:"
cat "$FILE_PATH"

#!/bin/bash

# 1.6.2 Ensure CRYPTO_POLICY is not explicitly set in /etc/sysconfig/sshd

TARGET_FILE="/etc/sysconfig/sshd"

# Check if file exists
if [ ! -f "$TARGET_FILE" ]; then
    echo "File $TARGET_FILE does not exist. Skipping."
    exit 0
fi

# Check if CRYPTO_POLICY line is already commented
if grep -Eq '^\s*#\s*CRYPTO_POLICY=' "$TARGET_FILE"; then
    echo "Setting already applied. CRYPTO_POLICY is already commented."
elif grep -Eq '^\s*CRYPTO_POLICY=' "$TARGET_FILE"; then
    sed -ri 's/^\s*(CRYPTO_POLICY\s*=.*)$/# \1/' "$TARGET_FILE"
    echo "Commented out CRYPTO_POLICY line in $TARGET_FILE."
else
    echo "No CRYPTO_POLICY setting found in $TARGET_FILE. Nothing to change."
fi

#!/bin/bash

# 4.2.12 Ensure sshd LoginGraceTime and related settings are configured

FILE_PATH="/etc/ssh/sshd_config"

# Lines to ensure
LINES=(
    "LoginGraceTime 60"
    "AllowUsers localadm bgadm root"
    "ClientAliveInterval 15"
    "ClientAliveCountMax 3"
    "DisableForwarding yes"
)

# Backup the original file (only once)
BACKUP_PATH="$FILE_PATH.bak"
if [ ! -f "$BACKUP_PATH" ]; then
    cp "$FILE_PATH" "$BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH"
fi

# Process each desired config line
for LINE in "${LINES[@]}"; do
    KEY=$(echo "$LINE" | awk '{print $1}')

    if grep -qE "^\s*#?\s*$KEY\b" "$FILE_PATH"; then
        # Replace existing key, whether commented or active
        sed -i "s|^\s*#\?\s*${KEY}\b.*|$LINE|" "$FILE_PATH"
        echo "Updated: $LINE"
    else
        # Append if the key doesn't exist
        echo "$LINE" >> "$FILE_PATH"
        echo "Added: $LINE"
    fi
done

#!/bin/bash

# 5.1.5 Disable SHA1 crypto via custom policy module

FILE="/etc/crypto-policies/policies/modules/NO-SHA1.pmod"

EXPECTED_CONTENT=$'# This is a subpolicy dropping the SHA1 hash and signature support\nhash = -SHA1\nsign = -*-SHA1\nsha1_in_certs = 0'

# Check if file exists and content matches
if [ -f "$FILE" ] && cmp -s <(echo -e "$EXPECTED_CONTENT") "$FILE"; then
    echo "File $FILE already exists with correct content. Skipping."
else
    printf '%s\n' \
        "# This is a subpolicy dropping the SHA1 hash and signature support" \
        "hash = -SHA1" \
        "sign = -*-SHA1" \
        "sha1_in_certs = 0" > "$FILE"
    echo "Created or updated $FILE with SHA1 restrictions."
fi


#!/bin/bash

# Define the login banner message
MESSAGE="This is a Singapore MINISTRY OF DEFENCE protected computer system. Unauthorised access, use, reproduction, possession, modification, interception, damage or transfer (including such attempts) of any content in this system are serious offences under the Computer Misuse Act and Cybersecurity Act (Chapter 50A). If found guilty, an offender can be fined up to \$100,000 and/or imprisoned up to 20 years. If you are not authorised to use this system, DO NOT LOG IN OR ATTEMPT TO LOG IN!"

# Paths to update
FILES=("/etc/motd" "/etc/issue.net")

for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ] && grep -Fxq "$MESSAGE" "$FILE"; then
        echo "$FILE already contains the correct banner. Skipping."
    else
        echo "$MESSAGE" > "$FILE"
        echo "Updated $FILE with login banner."
    fi
done

# Optional: Display the result
echo "Verifying contents..."
cat /etc/motd
cat /etc/issue.net


#!/bin/bash

# Define the file path
FILE_PATH="/etc/ssh/sshd_config"

# Backup the original file (optional but recommended)
sudo cp "$FILE_PATH" "$FILE_PATH.bak"

# Update the Banner line
if grep -q "^#Banner" "$FILE_PATH"; then
    sudo sed -i 's|^#Banner.*|Banner /etc/issue.net|' "$FILE_PATH"
elif grep -q "^Banner" "$FILE_PATH"; then
    sudo sed -i 's|^Banner.*|Banner /etc/issue.net|' "$FILE_PATH"
else
    echo "Banner /etc/issue.net" | sudo tee -a "$FILE_PATH" > /dev/null
fi

# Verify the changes
echo "Verifying the Banner configuration in $FILE_PATH..."
grep "^Banner" "$FILE_PATH"




#!/usr/bin/env bash

FSTAB_FILE="/etc/fstab"
EXTRA_OPTS="rw,nosuid,nodev,noexec,relatime"
FINAL_OPTS="defaults,$EXTRA_OPTS"

# Secure mount targets
declare -A MOUNTS
MOUNTS["/dev/mapper/rhel-tmp"]="/tmp"
MOUNTS["/dev/mapper/rhel-var"]="/var"
MOUNTS["/dev/mapper/rhel-home"]="/home"
MOUNTS["/dev/mapper/rhel-var_tmp"]="/var/tmp"
MOUNTS["/dev/mapper/rhel-var_log_audit"]="/var/log/audit"

echo "[*] Scanning and updating $FSTAB_FILE if needed..."

for DEV in "${!MOUNTS[@]}"; do
    MOUNT="${MOUNTS[$DEV]}"

    # Extract the matching fstab line (if exists)
    CURRENT_LINE=$(grep -E "^$DEV\s+$MOUNT\s+xfs" "$FSTAB_FILE")

    if [[ -n "$CURRENT_LINE" ]]; then
        # Check if current options match exactly
        CURRENT_OPTS=$(echo "$CURRENT_LINE" | awk '{print $4}')
        if [[ "$CURRENT_OPTS" == "$FINAL_OPTS" ]]; then
            echo "✔ $MOUNT already has correct options. Skipping."
        else
            echo "🔧 Updating $MOUNT options to: $FINAL_OPTS"
            sed -i -E "s|^($DEV\s+$MOUNT\s+xfs\s+)[^ ]*|\1$FINAL_OPTS|" "$FSTAB_FILE"
        fi
    else
        echo "➕ Adding secure entry for $MOUNT..."
        echo -e "$DEV\t$MOUNT\txfs\t$FINAL_OPTS\t0 0" >> "$FSTAB_FILE"
    fi
done

echo "[*] Done. You can run: mount -a --dry-run to verify syntax."

# 10. Blacklist gfs2 module safely
GFS2_CONF="/etc/modprobe.d/gfs2.conf"

# Ensure the file exists
touch "$GFS2_CONF"

# Add "blacklist gfs2" only if not already present
if ! grep -Fxq "blacklist gfs2" "$GFS2_CONF"; then
    echo "blacklist gfs2" >> "$GFS2_CONF"
fi

# Add "install gfs2 /bin/false" only if not already present
if ! grep -Fxq "install gfs2 /bin/false" "$GFS2_CONF"; then
    echo "install gfs2 /bin/false" >> "$GFS2_CONF"
fi

# 1. GRUB password setup (interactive)
if [ ! -f /boot/grub2/user.cfg ]; then
    echo "Setting GRUB password (requires manual input)..."
    grub2-setpassword
else
    echo "GRUB password already set. Skipping."
fi

# 2. GRUB file ownership and permissions
for FILE in /boot/grub2/grub.cfg /boot/grub2/grubenv /boot/grub2/user.cfg; do
    if [ -f "$FILE" ]; then
        chown root:root "$FILE"
        chmod u-x,go-rwx "$FILE"
    else
        echo "Warning: $FILE not found, skipping permission changes."
    fi
done

# 3. Kernel sysctl hardening
SYSCTL_CONF="/etc/sysctl.d/60-kernel_sysctl.conf"

grep -q "^kernel.randomize_va_space" "$SYSCTL_CONF" || echo "kernel.randomize_va_space = 2" >> "$SYSCTL_CONF"
sysctl -w kernel.randomize_va_space=2

grep -q "^kernel.yama.ptrace_scope" "$SYSCTL_CONF" || echo "kernel.yama.ptrace_scope = 1" >> "$SYSCTL_CONF"
sysctl -w kernel.yama.ptrace_scope=1

# 4. Disable core dumps
COREDUMP_CONF="/etc/systemd/coredump.conf"

if grep -qE "^\s*ProcessSizeMax\s*=" "$COREDUMP_CONF"; then
    echo "Updating existing ProcessSizeMax in coredump.conf..."
    sed -i -E 's|^\s*#?\s*ProcessSizeMax\s*=.*|ProcessSizeMax=0|' "$COREDUMP_CONF"
else
    echo "Appending ProcessSizeMax=0 to coredump.conf..."
    echo "ProcessSizeMax=0" >> "$COREDUMP_CONF"
fi


# 5. SSH crypto policy module
CRYPTO_FILE="/etc/crypto-policies/policies/modules/NOSSHCHACHA20.pmod"
if [ ! -f "$CRYPTO_FILE" ]; then
    echo 'cipher@SSH = -CHACHA20-POLY1305' > "$CRYPTO_FILE"
else
    grep -q "cipher@SSH = -CHACHA20-POLY1305" "$CRYPTO_FILE" || echo 'cipher@SSH = -CHACHA20-POLY1305' >> "$CRYPTO_FILE"
fi

# 6. Cron permission hardening
chown root:root /etc/crontab
chmod og-rwx /etc/crontab

if [ -f /etc/cron.deny ]; then
    chown root:root /etc/cron.deny
    chmod u-x,g-wx,o-rwx /etc/cron.deny
fi

# 7. at.allow & at.deny creation
for f in /etc/at.allow /etc/at.deny; do
    touch "$f"
    chown root:root "$f"
    chmod 640 "$f"
done

# 8. Disable IPv6
grubby --update-kernel=ALL --args="ipv6.disable=1"

# 9. Blacklist tipc
TIPC_CONF="/etc/modprobe.d/tipc.conf"

# Create file if it doesn't exist
touch "$TIPC_CONF"

# Add blacklist tipc if not present
if ! grep -q "^blacklist tipc" "$TIPC_CONF"; then
    echo "blacklist tipc" >> "$TIPC_CONF"
fi

# Add install tipc /bin/false if not present
if ! grep -q "^install tipc /bin/false" "$TIPC_CONF"; then
    echo "install tipc /bin/false" >> "$TIPC_CONF"
fi

# Remove the module if loaded
modprobe -r tipc 2>/dev/null
rmmod tipc 2>/dev/null


# 11. Ensure SELinux is not disabled via kernel args
KERNEL_CMDLINE=$(grubby --info=ALL | grep args | awk -F'=' '{print $2}')

if echo "$KERNEL_CMDLINE" | grep -qE "selinux=0|enforcing=0"; then
    echo "Removing 'selinux=0' and/or 'enforcing=0' from kernel args..."
    grubby --update-kernel=ALL --remove-args="selinux=0 enforcing=0"
else
    echo "SELinux kernel args already clean. No action needed."
fi


# 12. Add sudoers audit rules (non-duplicating)
AUDIT_RULE_FILE="/etc/audit/rules.d/50-scope.rules"

# Create file if it doesn't exist
touch "$AUDIT_RULE_FILE"

# Define both audit rules
RULE1='-w /etc/sudoers -p wa -k scope'
RULE2='-w /etc/sudoers.d -p wa -k scope'

# Add rule 1 if not already present
if ! grep -Fx -- "$RULE1" "$AUDIT_RULE_FILE" >/dev/null; then
    echo "$RULE1" >> "$AUDIT_RULE_FILE"
fi

# Add rule 2 if not already present
if ! grep -Fx -- "$RULE2" "$AUDIT_RULE_FILE" >/dev/null; then
    echo "$RULE2" >> "$AUDIT_RULE_FILE"
fi


# 13. Add user_emulation audit rules (non-duplicating)
AUDIT_USER_RULE="/etc/audit/rules.d/50-user_emulation.rules"

# Create file if it doesn't exist
touch "$AUDIT_USER_RULE"

RULE1='-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation'
RULE2='-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation'

# Add rules only if not already present
if ! grep -Fx -- "$RULE1" "$AUDIT_USER_RULE" >/dev/null; then
    echo "$RULE1" >> "$AUDIT_USER_RULE"
fi

if ! grep -Fx -- "$RULE2" "$AUDIT_USER_RULE" >/dev/null; then
    echo "$RULE2" >> "$AUDIT_USER_RULE"
fi


AUDIT_FILE="/etc/audit/rules.d/50-sudo.rules"
touch "$AUDIT_FILE"

RULE="-w /var/log/sudo.log -p wa -k sudo_log_file"

if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
    echo "$RULE" >> "$AUDIT_FILE"
    echo "Added audit rule for sudo log file: $SUDO_LOG_FILE"
else
    echo "Audit rule for sudo log file already exists. Skipping."
fi


# 15. Add time-change audit rules (idempotent)
AUDIT_FILE="/etc/audit/rules.d/50-time-change.rules"
touch "$AUDIT_FILE"

RULES=(
"-a always,exit -F arch=b64 -S adjtimex,settimeofday -k time-change"
"-a always,exit -F arch=b32 -S adjtimex,settimeofday -k time-change"
"-a always,exit -F arch=b64 -S clock_settime -F a0=0x0 -k time-change"
"-a always,exit -F arch=b32 -S clock_settime -F a0=0x0 -k time-change"
"-w /etc/localtime -p wa -k time-change"
)

for RULE in "${RULES[@]}"; do
    if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
        echo "$RULE" >> "$AUDIT_FILE"
        echo "Added: $RULE"
    else
        echo "Already exists: $RULE"
    fi
done

# 16. Add system-locale audit rules (idempotent)
AUDIT_FILE="/etc/audit/rules.d/50-system_locale.rules"
touch "$AUDIT_FILE"

RULES=(
"-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale"
"-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale"
"-w /etc/issue -p wa -k system-locale"
"-w /etc/issue.net -p wa -k system-locale"
"-w /etc/hosts -p wa -k system-locale"
"-w /etc/hostname -p wa -k system-locale"
"-w /etc/sysconfig/network -p wa -k system-locale"
"-w /etc/sysconfig/network-scripts/ -p wa -k system-locale"
"-w /etc/NetworkManager -p wa -k system-locale"
)

for RULE in "${RULES[@]}"; do
    if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
        echo "$RULE" >> "$AUDIT_FILE"
        echo "Added: $RULE"
    else
        echo "Already exists: $RULE"
    fi
done

# 17. Add audit rules for privileged commands dynamically
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    AUDIT_RULE_FILE="/etc/audit/rules.d/50-privileged.rules"
    NEW_DATA=()

    # Get all nodev partitions that are NOT noexec or nosuid
    for PARTITION in $(findmnt -n -l -k -it $(awk '/nodev/ { print $2 }' /proc/filesystems | paste -sd,) \
        | grep -Pv "noexec|nosuid" | awk '{print $1}'); do

        # Find all SUID/SGID files and format audit rules
        readarray -t DATA < <(find "${PARTITION}" -xdev -perm /6000 -type f 2>/dev/null | awk -v UID_MIN="${UID_MIN}" \
            '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=" UID_MIN " -F auid!=unset -k privileged"}')

        for ENTRY in "${DATA[@]}"; do
            NEW_DATA+=("${ENTRY}")
        done
    done

    # Load current rules (safely if file exists)
    OLD_DATA=()
    if [ -f "$AUDIT_RULE_FILE" ]; then
        readarray -t OLD_DATA < "$AUDIT_RULE_FILE"
    fi

    # Merge and de-duplicate rules
    COMBINED_DATA=( "${OLD_DATA[@]}" "${NEW_DATA[@]}" )
    printf '%s\n' "${COMBINED_DATA[@]}" | sort -u > "${AUDIT_RULE_FILE}"
}

# 18. Add audit rules for file access denials (EACCES/EPERM)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-access.rules"
        touch "$AUDIT_FILE"

        RULES=(
"-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=$UID_MIN -F auid!=unset -k access"
"-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM  -F auid>=$UID_MIN -F auid!=unset -k access"
"-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=$UID_MIN -F auid!=unset -k access"
"-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM  -F auid>=$UID_MIN -F auid!=unset -k access"
        )

        for RULE in "${RULES[@]}"; do
            if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
                echo "$RULE" >> "$AUDIT_FILE"
                echo "Added: $RULE"
            else
                echo "Already exists: $RULE"
            fi
        done
    else
        echo "ERROR: Variable 'UID_MIN' is unset in /etc/login.defs"
    fi
}

# 19. Add audit rules for identity-related files (idempotent)
AUDIT_FILE="/etc/audit/rules.d/50-identity.rules"
touch "$AUDIT_FILE"

RULES=(
"-w /etc/group -p wa -k identity"
"-w /etc/passwd -p wa -k identity"
"-w /etc/gshadow -p wa -k identity"
"-w /etc/shadow -p wa -k identity"
"-w /etc/security/opasswd -p wa -k identity"
"-w /etc/nsswitch.conf -p wa -k identity"
"-w /etc/pam.conf -p wa -k identity"
"-w /etc/pam.d -p wa -k identity"
)

for RULE in "${RULES[@]}"; do
    if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
        echo "$RULE" >> "$AUDIT_FILE"
        echo "Added: $RULE"
    else
        echo "Already exists: $RULE"
    fi
done

# 20. Add audit rules for permission modifications (idempotent)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-perm_mod.rules"
        touch "$AUDIT_FILE"

        RULES=(
"-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=$UID_MIN -F auid!=unset -F key=perm_mod"
"-a always,exit -F arch=b64 -S chown,fchown,lchown,fchownat -F auid>=$UID_MIN -F auid!=unset -F key=perm_mod"
"-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=$UID_MIN -F auid!=unset -F key=perm_mod"
"-a always,exit -F arch=b32 -S lchown,fchown,chown,fchownat -F auid>=$UID_MIN -F auid!=unset -F key=perm_mod"
"-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=$UID_MIN -F auid!=unset -F key=perm_mod"
"-a always,exit -F arch=b32 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=$UID_MIN -F auid!=unset -F key=perm_mod"
        )

        for RULE in "${RULES[@]}"; do
            if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
                echo "$RULE" >> "$AUDIT_FILE"
                echo "Added: $RULE"
            else
                echo "Already exists: $RULE"
            fi
        done
    else
        echo "ERROR: Variable 'UID_MIN' is unset in /etc/login.defs"
    fi
}



# 21. Add audit rules for mount system calls (idempotent)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-mounts.rules"
        touch "$AUDIT_FILE"

        RULES=(
"-a always,exit -F arch=b32 -S mount -F auid>=$UID_MIN -F auid!=unset -k mounts"
"-a always,exit -F arch=b64 -S mount -F auid>=$UID_MIN -F auid!=unset -k mounts"
        )

        for RULE in "${RULES[@]}"; do
            if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
                echo "$RULE" >> "$AUDIT_FILE"
                echo "Added: $RULE"
            else
                echo "Already exists: $RULE"
            fi
        done
    else
        echo "ERROR: Variable 'UID_MIN' is unset in /etc/login.defs"
    fi
}


# 22. Add audit rules for session tracking (idempotent)
AUDIT_FILE="/etc/audit/rules.d/50-session.rules"
touch "$AUDIT_FILE"

RULES=(
"-w /var/run/utmp -p wa -k session"
"-w /var/log/wtmp -p wa -k session"
"-w /var/log/btmp -p wa -k session"
)

for RULE in "${RULES[@]}"; do
    if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
        echo "$RULE" >> "$AUDIT_FILE"
        echo "Added: $RULE"
    else
        echo "Already exists: $RULE"
    fi
done


# 23. Add audit rules for login tracking (idempotent)
AUDIT_FILE="/etc/audit/rules.d/50-login.rules"
touch "$AUDIT_FILE"

RULES=(
"-w /var/log/lastlog -p wa -k logins"
"-w /var/run/faillock -p wa -k logins"
)

for RULE in "${RULES[@]}"; do
    if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
        echo "$RULE" >> "$AUDIT_FILE"
        echo "Added: $RULE"
    else
        echo "Already exists: $RULE"
    fi
done


# 24. Add audit rules for file deletion actions (idempotent)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-delete.rules"
        touch "$AUDIT_FILE"

        RULES=(
"-a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F auid>=$UID_MIN -F auid!=unset -F key=delete"
"-a always,exit -F arch=b32 -S rename,unlink,unlinkat,renameat -F auid>=$UID_MIN -F auid!=unset -F key=delete"
        )

        for RULE in "${RULES[@]}"; do
            if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
                echo "$RULE" >> "$AUDIT_FILE"
                echo "Added: $RULE"
            else
                echo "Already exists: $RULE"
            fi
        done
    else
        echo "ERROR: UID_MIN is unset in /etc/login.defs"
    fi
}

# 25. Add audit rules for SELinux MAC policy changes (idempotent)
AUDIT_FILE="/etc/audit/rules.d/50-MAC-policy.rules"
touch "$AUDIT_FILE"

RULES=(
"-w /etc/selinux -p wa -k MAC-policy"
"-w /usr/share/selinux -p wa -k MAC-policy"
)

for RULE in "${RULES[@]}"; do
    if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
        echo "$RULE" >> "$AUDIT_FILE"
        echo "Added: $RULE"
    else
        echo "Already exists: $RULE"
    fi
done


# 26. Add audit rule for SELinux context changes using chcon (idempotent)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-perm_chng.rules"
        touch "$AUDIT_FILE"

        RULE="-a always,exit -F path=/usr/bin/chcon -F perm=x -F auid>=$UID_MIN -F auid!=unset -k perm_chng"

        if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
            echo "$RULE" >> "$AUDIT_FILE"
            echo "Added: $RULE"
        else
            echo "Already exists: $RULE"
        fi
    else
        echo "ERROR: UID_MIN is unset in /etc/login.defs"
    fi
}


# 27. Add audit rule for ACL permission changes using setfacl (idempotent)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-perm_chng.rules"
        touch "$AUDIT_FILE"

        RULE="-a always,exit -F path=/usr/bin/setfacl -F perm=x -F auid>=$UID_MIN -F auid!=unset -k perm_chng"

        if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
            echo "$RULE" >> "$AUDIT_FILE"
            echo "Added: $RULE"
        else
            echo "Already exists: $RULE"
        fi
    else
        echo "ERROR: UID_MIN is unset in /etc/login.defs"
    fi
}


# 28. Add audit rule for ACL permission changes using chacl (idempotent)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-perm_chng.rules"
        touch "$AUDIT_FILE"

        RULE="-a always,exit -F path=/usr/bin/chacl -F perm=x -F auid>=$UID_MIN -F auid!=unset -k perm_chng"

        if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
            echo "$RULE" >> "$AUDIT_FILE"
            echo "Added: $RULE"
        else
            echo "Already exists: $RULE"
        fi
    else
        echo "ERROR: UID_MIN is unset in /etc/login.defs"
    fi
}


# 29. Add audit rule for user account modifications via usermod (idempotent)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-usermod.rules"
        touch "$AUDIT_FILE"

        RULE="-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=$UID_MIN -F auid!=unset -k usermod"

        if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
            echo "$RULE" >> "$AUDIT_FILE"
            echo "Added: $RULE"
        else
            echo "Already exists: $RULE"
        fi
    else
        echo "ERROR: UID_MIN is unset in /etc/login.defs"
    fi
}


# 30. Add audit rules for kernel module operations (idempotent)
{
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    if [ -n "$UID_MIN" ]; then
        AUDIT_FILE="/etc/audit/rules.d/50-kernel_modules.rules"
        touch "$AUDIT_FILE"

        RULES=(
"-a always,exit -F arch=b64 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=$UID_MIN -F auid!=unset -k kernel_modules"
"-a always,exit -F path=/usr/bin/kmod -F perm=x -F auid>=$UID_MIN -F auid!=unset -k kernel_modules"
        )

        for RULE in "${RULES[@]}"; do
            if ! grep -Fx -- "$RULE" "$AUDIT_FILE" >/dev/null; then
                echo "$RULE" >> "$AUDIT_FILE"
                echo "Added: $RULE"
            else
                echo "Already exists: $RULE"
            fi
        done
    else
        echo "ERROR: UID_MIN is unset in /etc/login.defs"
    fi
}


# 31. Set final audit rule to make rule loading strict (idempotent)
FINAL_RULE_FILE="/etc/audit/rules.d/99-finalize.rules"
touch "$FINAL_RULE_FILE"

FINAL_RULE="-e 2"

if ! grep -Fx -- "$FINAL_RULE" "$FINAL_RULE_FILE" >/dev/null; then
    echo "$FINAL_RULE" >> "$FINAL_RULE_FILE"
    echo "Added: $FINAL_RULE"
else
    echo "Already exists: $FINAL_RULE"
fi

#!/bin/bash

FILE="/etc/crypto-policies/policies/modules/NO-SHA1.pmod"
LINES=(
    "# This is a subpolicy dropping the SHA1 hash and signature support"
    "hash = -SHA1"
    "sign = -*-SHA1"
    "sha1_in_certs = 0"
)

# Ensure the parent directory exists
mkdir -p "$(dirname "$FILE")"

# Create the file if it doesn't exist
[ ! -f "$FILE" ] && touch "$FILE"

ADDED=0

for LINE in "${LINES[@]}"; do
    if ! grep -Fxq "$LINE" "$FILE"; then
        echo "$LINE" >> "$FILE"
        echo "Added: $LINE"
        ADDED=1
    fi
done

if [ "$ADDED" -eq 0 ]; then
    echo "No changes made. All required lines already exist in $FILE"
else
    echo "Final content of $FILE:"
    cat "$FILE"
fi


#!/bin/bash

FILE="/etc/crypto-policies/policies/modules/NO-SSHWEAKMACS.pmod"
LINES=(
    "# This is a subpolicy to disable weak MACs"
    "# for the SSH protocol (libssh and OpenSSH)"
    "mac@SSH = -HMAC-MD5* -UMAC-64* -UMAC-128*"
)

# Ensure the directory exists
mkdir -p "$(dirname "$FILE")"

# Create the file if it doesn't exist
[ ! -f "$FILE" ] && touch "$FILE"

ADDED=0

for LINE in "${LINES[@]}"; do
    if ! grep -Fxq "$LINE" "$FILE"; then
        echo "$LINE" >> "$FILE"
        echo "Added: $LINE"
        ADDED=1
    fi
done

if [ "$ADDED" -eq 0 ]; then
    echo "No changes made. All required lines already exist in $FILE"
else
    echo "Final content of $FILE:"
    cat "$FILE"
fi

#!/bin/bash

# 4.2.12 Ensure sshd LoginGraceTime is configured

FILE_PATH="/etc/ssh/sshd_config"
BACKUP_PATH="${FILE_PATH}.bak"

# Lines to ensure
LINES=(
    "LoginGraceTime 60"
    "AllowUsers localadm bgadm root"
    "ClientAliveInterval 15"
    "ClientAliveCountMax 3"
    "DisableForwarding yes"
)

# Backup original
cp "$FILE_PATH" "$BACKUP_PATH"

for LINE in "${LINES[@]}"; do
    KEY=$(echo "$LINE" | awk '{print $1}')

    # If key exists, replace the line
    if grep -qE "^$KEY\s+" "$FILE_PATH"; then
        sed -i "s|^$KEY\s\+.*|$LINE|" "$FILE_PATH"
        echo "Updated $KEY to: $LINE"

    # If key doesn't exist at all, append it
    elif ! grep -Fxq "$LINE" "$FILE_PATH"; then
        echo "$LINE" >> "$FILE_PATH"
        echo "Added new line: $LINE"
    else
        echo "Line already exists: $LINE"
    fi
done

#!/bin/bash

FILE_PATH="/etc/ssh/sshd_config"
BACKUP_PATH="${FILE_PATH}.bak"

SETTING="GSSAPIAuthentication no"
KEY=$(echo "$SETTING" | awk '{print $1}')

# Backup once
[ -f "$BACKUP_PATH" ] || cp "$FILE_PATH" "$BACKUP_PATH"

if grep -Eq "^\s*#?\s*${KEY}\b" "$FILE_PATH"; then
    sed -ri "s|^\s*#?\s*${KEY}\b.*|$SETTING|" "$FILE_PATH"
    echo "Updated or uncommented: $SETTING"
else
    echo "$SETTING" >> "$FILE_PATH"
    echo "Appended: $SETTING"
fi

#!/bin/bash

PROFILE_NAME="custom-profile"
BACKUP_NAME="PAM_CONFIG_BACKUUP"
PROFILE_PATH="/etc/authselect/custom/$PROFILE_NAME"

# Check if the profile already exists
if [ -d "$PROFILE_PATH" ]; then
    echo "Authselect custom profile '$PROFILE_NAME' already exists. Skipping creation."
else
    echo "Creating custom authselect profile '$PROFILE_NAME' based on sssd..."
    authselect create-profile "$PROFILE_NAME" -b sssd
    echo "Profile '$PROFILE_NAME' created successfully."
fi

# Check if the profile is already selected
CURRENT_PROFILE=$(authselect current | awk '/Profile ID:/ {print $NF}')
if [[ "$CURRENT_PROFILE" == "custom/$PROFILE_NAME" ]]; then
    echo "Authselect is already using 'custom/$PROFILE_NAME'. Skipping selection."
else
    echo "Selecting custom profile 'custom/$PROFILE_NAME' with backup '$BACKUP_NAME'..."
    authselect select "custom/$PROFILE_NAME" --backup="$BACKUP_NAME" --force
    echo "Profile 'custom/$PROFILE_NAME' selected successfully."
fi

#!/bin/bash

FILE="/etc/crypto-policies/policies/modules/NO-WEAKMAC.pmod"

# Lines to add
LINES=(
    "# This is a subpolicy to disable weak macs"
    "mac = -*-64"
)

# Create file if it doesn't exist
if [ ! -f "$FILE" ]; then
    touch "$FILE"
    echo "File '$FILE' created."
fi

# Track if any changes were made
CHANGED=0

# Loop through and add missing lines
for LINE in "${LINES[@]}"; do
    if ! grep -Fxq "$LINE" "$FILE"; then
        echo "$LINE" >> "$FILE"
        echo "Added: $LINE"
        CHANGED=1
    fi
done

# Final message
if [ "$CHANGED" -eq 0 ]; then
    echo "All lines already exist in '$FILE'. Nothing changed."
else
    echo "File '$FILE' updated successfully."
fi


#!/bin/bash

FILE="/etc/crypto-policies/policies/modules/NO-SSHCBC.pmod"

# Lines to add
LINES=(
    "# This is a subpolicy to disable all CBC mode ciphers"
    "# for the SSH protocol (libssh and OpenSSH)"
    "cipher@SSH = -*-CBC"
)

# Create the file if it doesn't exist
if [ ! -f "$FILE" ]; then
    touch "$FILE"
    echo "File '$FILE' created."
fi

# Track if changes were made
CHANGED=0

# Append missing lines
for LINE in "${LINES[@]}"; do
    if ! grep -Fxq "$LINE" "$FILE"; then
        echo "$LINE" >> "$FILE"
        echo "Added: $LINE"
        CHANGED=1
    fi
done

# Final message
if [ "$CHANGED" -eq 0 ]; then
    echo "All lines already exist in '$FILE'. Nothing changed."
else
    echo "File '$FILE' updated successfully."
fi

#!/bin/bash

CONF_FILE="/etc/systemd/coredump.conf"
TARGET_LINE="ProcessSizeMax=0"

# Check if the exact line already exists
if grep -Fxq "$TARGET_LINE" "$CONF_FILE"; then
    echo "Line already set: $TARGET_LINE"
else
    # If line exists with different value (commented or not), replace it
    if grep -Eq "^\s*#?\s*ProcessSizeMax=" "$CONF_FILE"; then
        sudo sed -i "s|^\s*#\?\s*ProcessSizeMax=.*|$TARGET_LINE|" "$CONF_FILE"
        echo "Updated existing ProcessSizeMax line to: $TARGET_LINE"
    else
        # Line does not exist at all, append it
        echo "$TARGET_LINE" | sudo tee -a "$CONF_FILE" > /dev/null
        echo "Appended: $TARGET_LINE"
    fi
fi

#!/bin/bash

# 1.4.4 Ensure core dump storage is disabled

FILE_PATH="/etc/systemd/coredump.conf"
TARGET_LINE="Storage=none"

# Ensure the file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: $FILE_PATH does not exist."
    exit 1
fi

# Check if the exact line already exists
if grep -Fxq "$TARGET_LINE" "$FILE_PATH"; then
    echo "Line already set: $TARGET_LINE"
else
    # If line exists with different value (commented or not), replace it
    if grep -Eq "^\s*#?\s*Storage=" "$FILE_PATH"; then
        sudo sed -i "s|^\s*#\?\s*Storage=.*|$TARGET_LINE|" "$FILE_PATH"
        echo "Updated existing Storage line to: $TARGET_LINE"
    else
        # Line does not exist at all, append it
        echo "$TARGET_LINE" | sudo tee -a "$FILE_PATH" > /dev/null
        echo "Appended: $TARGET_LINE"
    fi
fi


#!/bin/bash

CONF_FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"
KEY="net.ipv4.ip_forward"
VALUE="0"
LINE="${KEY} = ${VALUE}"

# Create file if it doesn't exist
if [ ! -f "$CONF_FILE" ]; then
    sudo touch "$CONF_FILE"
    echo "Created file: $CONF_FILE"
fi

# Check if the exact line already exists
if grep -Fxq "$LINE" "$CONF_FILE"; then
    echo "✅ Line already set: $LINE"
elif grep -q "^${KEY}" "$CONF_FILE"; then
    sudo sed -i "s|^${KEY}.*|$LINE|" "$CONF_FILE"
    echo "🔄 Updated existing $KEY to $VALUE"
else
    echo "$LINE" | sudo tee -a "$CONF_FILE" > /dev/null
    echo "➕ Appended: $LINE"
fi

#!/bin/bash

# Define the sysctl setting and target file
SETTING="net.ipv4.icmp_ignore_bogus_error_responses = 1"
FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"

# Create the file if it does not exist
if [ ! -f "$FILE" ]; then
    sudo touch "$FILE"
    echo "[+] Created file: $FILE"
fi

# Check if the exact line is already in the file
if grep -Fxq "$SETTING" "$FILE"; then
    echo "[=] Setting already present in $FILE. No changes made."
elif grep -q "^net.ipv4.icmp_ignore_bogus_error_responses" "$FILE"; then
    sudo sed -i "s|^net.ipv4.icmp_ignore_bogus_error_responses.*|$SETTING|" "$FILE"
    echo "[~] Updated existing setting to: $SETTING"
else
    echo "$SETTING" | sudo tee -a "$FILE" > /dev/null
    echo "[+] Appended: $SETTING"
fi


#!/bin/bash

CONF_FILE="/etc/sysctl.d/60-netipv6_sysctl.conf"
KEY="net.ipv6.conf.all.forwarding"
VALUE="0"
LINE="${KEY} = ${VALUE}"

# Create the file if it doesn't exist
if [ ! -f "$CONF_FILE" ]; then
    sudo touch "$CONF_FILE"
    echo "[+] Created file: $CONF_FILE"
fi

# Check if exact line exists
if grep -Fxq "$LINE" "$CONF_FILE"; then
    echo "[=] Line already set: $LINE"
elif grep -q "^${KEY}" "$CONF_FILE"; then
    sudo sed -i "s|^${KEY}.*|$LINE|" "$CONF_FILE"
    echo "[~] Updated existing $KEY to $VALUE"
else
    echo "$LINE" | sudo tee -a "$CONF_FILE" > /dev/null
    echo "[+] Appended: $LINE"
fi

#!/bin/bash

CONF_FILE="/etc/sysctl.d/60-netipv6_sysctl.conf"

# Create the file if it doesn't exist
if [ ! -f "$CONF_FILE" ]; then
    sudo touch "$CONF_FILE"
    echo "[+] Created file: $CONF_FILE"
fi

declare -A SETTINGS=(
    ["net.ipv6.conf.all.accept_ra"]="0"
    ["net.ipv6.conf.default.accept_ra"]="0"
)

for KEY in "${!SETTINGS[@]}"; do
    VALUE="${SETTINGS[$KEY]}"
    LINE="${KEY} = ${VALUE}"

    if grep -Fxq "$LINE" "$CONF_FILE"; then
        echo "[=] Line already set: $LINE"
    elif grep -Eq "^\s*${KEY}\b" "$CONF_FILE"; then
        sudo sed -i "s|^\s*${KEY}.*|$LINE|" "$CONF_FILE"
        echo "[~] Updated: $LINE"
    else
        echo "$LINE" | sudo tee -a "$CONF_FILE" > /dev/null
        echo "[+] Appended: $LINE"
    fi
done

#!/bin/bash

CONF_FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"

# Ensure the config file exists
if [ ! -f "$CONF_FILE" ]; then
    sudo touch "$CONF_FILE"
    echo "[+] Created config file: $CONF_FILE"
fi

declare -A SETTINGS=(
    ["net.ipv4.conf.all.accept_redirects"]="0"
    ["net.ipv4.conf.default.accept_redirects"]="0"
)

for KEY in "${!SETTINGS[@]}"; do
    VALUE="${SETTINGS[$KEY]}"
    LINE="${KEY} = ${VALUE}"

    if grep -Fxq "$LINE" "$CONF_FILE"; then
        echo "[=] Already set: $LINE"
    elif grep -Eq "^\s*${KEY}\b" "$CONF_FILE"; then
        sudo sed -i "s|^\s*${KEY}.*|$LINE|" "$CONF_FILE"
        echo "[~] Updated existing $KEY to $VALUE"
    else
        echo "$LINE" | sudo tee -a "$CONF_FILE" > /dev/null
        echo "[+] Appended: $LINE"
    fi
done


#!/bin/bash

CONF_FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"

# Create file if it doesn't exist
if [ ! -f "$CONF_FILE" ]; then
    sudo touch "$CONF_FILE"
    echo "Created file: $CONF_FILE"
fi

# List of settings to apply
SETTINGS=(
    "net.ipv4.conf.all.accept_source_route = 0"
    "net.ipv4.conf.default.accept_source_route = 0"
)

for LINE in "${SETTINGS[@]}"; do
    KEY=$(echo "$LINE" | cut -d= -f1 | xargs)
    VALUE=$(echo "$LINE" | cut -d= -f2- | xargs)

    if grep -Eq "^\s*${KEY}\s*=\s*${VALUE}\s*$" "$CONF_FILE"; then
        echo "✅ $KEY already set correctly. Skipping..."
    elif grep -Eq "^\s*${KEY}\s*=" "$CONF_FILE"; then
        sudo sed -i "s|^\s*${KEY}\s*=.*|${KEY} = ${VALUE}|" "$CONF_FILE"
        echo "✏️ Updated $KEY to correct value."
    else
        echo "$KEY = $VALUE" | sudo tee -a "$CONF_FILE" > /dev/null
        echo "➕ Added: $KEY = $VALUE"
    fi
done


#!/bin/bash

# Define the sysctl settings and target file
SYSCTL_SETTINGS=(
    "net.ipv4.conf.all.send_redirects = 0"
    "net.ipv4.conf.default.send_redirects = 0"
)
FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"

# Ensure the file exists
if [ ! -f "$FILE" ]; then
    sudo touch "$FILE"
    echo "[+] Created file: $FILE"
fi

# Loop through each setting
for LINE in "${SYSCTL_SETTINGS[@]}"; do
    KEY=$(echo "$LINE" | cut -d= -f1 | xargs)
    VALUE=$(echo "$LINE" | cut -d= -f2- | xargs)

    if grep -Eq "^\s*${KEY}\s*=\s*${VALUE}\s*$" "$FILE"; then
        echo "[=] Setting already correct: $LINE"
    elif grep -Eq "^\s*${KEY}\s*=" "$FILE"; then
        sudo sed -i "s|^\s*${KEY}\s*=.*|${KEY} = ${VALUE}|" "$FILE"
        echo "[~] Updated existing $KEY to: $VALUE"
    else
        echo "${KEY} = ${VALUE}" | sudo tee -a "$FILE" > /dev/null
        echo "[+] Added setting: ${KEY} = ${VALUE}"
    fi
done

#!/bin/bash

# Target sysctl config file
FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"
KEY="net.ipv4.icmp_echo_ignore_broadcasts"
VALUE="1"
SETTING="${KEY} = ${VALUE}"

# Ensure the file exists
if [ ! -f "$FILE" ]; then
    sudo touch "$FILE"
    echo "[+] Created file: $FILE"
fi

# Check and update or append
if grep -Eq "^\s*${KEY}\s*=\s*${VALUE}\s*$" "$FILE"; then
    echo "[=] Setting already correct: $SETTING"
elif grep -Eq "^\s*${KEY}\s*=" "$FILE"; then
    sudo sed -i "s|^\s*${KEY}\s*=.*|${SETTING}|" "$FILE"
    echo "[~] Updated existing $KEY to: $VALUE"
else
    echo "$SETTING" | sudo tee -a "$FILE" > /dev/null
    echo "[+] Appended: $SETTING"
fi

#!/bin/bash

FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"
sudo touch "$FILE"

SYSCTL_LINES=(
  "net.ipv4.conf.all.secure_redirects = 0"
  "net.ipv4.conf.default.secure_redirects = 0"
)

for LINE in "${SYSCTL_LINES[@]}"; do
    if grep -Fxq "$LINE" "$FILE"; then
        echo "[=] Already set: $LINE"
    else
        echo "$LINE" | sudo tee -a "$FILE" > /dev/null
        echo "[+] Added: $LINE"
    fi
done

#!/bin/bash

FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"
sudo touch "$FILE"

SYSCTL_LINES=(
  "net.ipv4.conf.all.log_martians = 1"
  "net.ipv4.conf.default.log_martians = 1"
)

for LINE in "${SYSCTL_LINES[@]}"; do
    if grep -Fxq "$LINE" "$FILE"; then
        echo "[=] Already set: $LINE"
    else
        echo "$LINE" | sudo tee -a "$FILE" > /dev/null
        echo "[+] Added: $LINE"
    fi
done

#!/bin/bash

FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"
sudo touch "$FILE"

LINE="net.ipv4.tcp_syncookies = 1"

if grep -Fxq "$LINE" "$FILE"; then
    echo "[=] Already set: $LINE"
else
    echo "$LINE" | sudo tee -a "$FILE" > /dev/null
    echo "[+] Added: $LINE"
fi


#!/bin/bash

# Track changes and output messages
l_output=""
l_output2=""

# Detect SSH group name
l_ssh_group_name="$(awk -F: '($1 ~ /^(ssh_keys|_?ssh)$/) {print $1}' /etc/group)"

# Function to fix file access
f_file_access_fix() {
    while IFS=: read -r l_file_mode l_file_owner l_file_group; do
        echo "Checking: $l_file (mode: $l_file_mode, owner: $l_file_owner, group: $l_file_group)"
        l_out2=""
        [ "$l_file_group" = "$l_ssh_group_name" ] && l_pmask="0137" || l_pmask="0177"
        l_maxperm="$( printf '%o' $(( 0777 & ~$l_pmask )) )"

        # Check and correct permissions
        if [ $(( l_file_mode & l_pmask )) -gt 0 ]; then
            l_out2+="\n - Mode: $l_file_mode should be $l_maxperm. Updating."
            if [ "$l_file_group" = "$l_ssh_group_name" ]; then
                chmod u-x,g-wx,o-rwx "$l_file"
            else
                chmod u-x,go-rwx "$l_file"
            fi
        fi

        # Check and correct owner
        if [ "$l_file_owner" != "root" ]; then
            l_out2+="\n - Owner: $l_file_owner should be root. Changing."
            chown root "$l_file"
        fi

        # Check and correct group
        if [[ ! "$l_file_group" =~ ($l_ssh_group_name|root) ]]; then
            l_new_group="${l_ssh_group_name:-root}"
            l_out2+="\n - Group: $l_file_group should be $l_new_group. Changing."
            chgrp "$l_new_group" "$l_file"
        fi

        if [ -n "$l_out2" ]; then
            l_output2+="\n - File: $l_file$l_out2"
        else
            l_output+="\n - File: $l_file is already correctly configured."
        fi
    done < <(stat -Lc '%#a:%U:%G' "$l_file")
}

# Process SSH private key files
while IFS= read -r -d $'\0' l_file; do
    if ssh-keygen -lf "$l_file" &>/dev/null; then
        if file "$l_file" | grep -Piq '\bopenssh\s+[^\n\r]*private\s+key\b'; then
            f_file_access_fix
        fi
    fi
done < <(find -L /etc/ssh -xdev -type f -print0 2>/dev/null)

# Print results
if [ -z "$l_output2" ]; then
    echo -e "\n[✔] All SSH key files already have correct permissions."
else
    echo -e "\n[⚠] Remediation results:$l_output2"
fi


#!/bin/bash

# Temp file for sudoers modification
TEMP_SUDOERS=$(mktemp)

# Backup original sudoers
sudo cp /etc/sudoers /etc/sudoers.bak

# Check if the line already exists
if sudo grep -q "^Defaults\s\+use_pty" /etc/sudoers; then
    echo "[=] 'Defaults use_pty' already set in /etc/sudoers. Skipping..."
else
    # Append the line
    sudo cp /etc/sudoers "$TEMP_SUDOERS"
    echo "Defaults use_pty" | sudo tee -a "$TEMP_SUDOERS" > /dev/null

    # Validate syntax with visudo
    if sudo visudo -cf "$TEMP_SUDOERS"; then
        sudo cp "$TEMP_SUDOERS" /etc/sudoers
        echo "[+] 'Defaults use_pty' added to /etc/sudoers successfully."
    else
        echo "[!] Syntax error detected. Aborting. Restore from /etc/sudoers.bak if needed."
    fi
fi

# Cleanup
rm -f "$TEMP_SUDOERS"


#!/bin/bash

# Desired line to add
TARGET_LINE='Defaults logfile="/var/log/sudo.log"'
TEMP_SUDOERS=$(mktemp)

# Backup the original sudoers file
sudo cp /etc/sudoers /etc/sudoers.bak

# Check if the line already exists
if sudo grep -q "^$TARGET_LINE" /etc/sudoers; then
    echo "[=] '$TARGET_LINE' already set in /etc/sudoers. Skipping..."
else
    # Append the line to a temporary file
    sudo cp /etc/sudoers "$TEMP_SUDOERS"
    echo "$TARGET_LINE" | sudo tee -a "$TEMP_SUDOERS" > /dev/null

    # Validate using visudo
    if sudo visudo -cf "$TEMP_SUDOERS"; then
        sudo cp "$TEMP_SUDOERS" /etc/sudoers
        echo "[+] '$TARGET_LINE' added successfully to /etc/sudoers."
    else
        echo "[!] Syntax error in modified sudoers. Aborting. Restore from /etc/sudoers.bak if needed."
    fi
fi

# Clean up
rm -f "$TEMP_SUDOERS"


#!/bin/bash

FILE="/etc/security/pwquality.conf"
KEY="minclass"
VALUE="4"
TARGET_LINE="$KEY = $VALUE"

# Backup the original file
sudo cp "$FILE" "${FILE}.bak"

# Check if the exact line exists
if grep -q "^$KEY[[:space:]]*=[[:space:]]*$VALUE" "$FILE"; then
    echo "[=] '$TARGET_LINE' already set. No changes made."
else
    # Check if any 'minclass' line exists (commented or not)
    if grep -q "^[#]*[[:space:]]*$KEY[[:space:]]*=" "$FILE"; then
        # Replace existing (even if commented)
        sudo sed -i "s|^[#]*[[:space:]]*$KEY[[:space:]]*=.*|$TARGET_LINE|" "$FILE"
        echo "[+] Updated '$KEY' to '$VALUE'."
    else
        # Append if the key is missing entirely
        echo "$TARGET_LINE" | sudo tee -a "$FILE" > /dev/null
        echo "[+] Appended '$TARGET_LINE' to $FILE."
    fi
fi



#!/bin/bash

FILE="/etc/ssh/sshd_config"
BACKUP="$FILE.bak"

# Backup the original config if not already done
if [ ! -f "$BACKUP" ]; then
    sudo cp "$FILE" "$BACKUP"
    echo "[+] Backup created at $BACKUP"
fi

# Define desired settings
declare -A SETTINGS
SETTINGS["MaxAuthTries"]="4"
SETTINGS["MaxStartups"]="10:30:60"

for KEY in "${!SETTINGS[@]}"; do
    VALUE="${SETTINGS[$KEY]}"
    TARGET_LINE="$KEY $VALUE"

    if grep -Eq "^$KEY[[:space:]]+$VALUE" "$FILE"; then
        echo "[=] $TARGET_LINE already set. Skipping..."
    elif grep -Eq "^#?$KEY[[:space:]]+" "$FILE"; then
        sudo sed -i "s/^#\?$KEY[[:space:]]\+.*/$TARGET_LINE/" "$FILE"
        echo "[~] Updated: $TARGET_LINE"
    else
        echo "$TARGET_LINE" | sudo tee -a "$FILE" > /dev/null
        echo "[+] Appended: $TARGET_LINE"
    fi
done

echo -e "\n[✔] SSH configuration updated. You may want to run: sudo systemctl restart sshd"




#!/bin/bash

CONF_FILE="/etc/sysctl.d/60-netipv6_sysctl.conf"
declare -A SETTINGS=(
    ["net.ipv6.conf.all.accept_redirects"]="0"
    ["net.ipv6.conf.default.accept_redirects"]="0"
)

for KEY in "${!SETTINGS[@]}"; do
    VALUE="${SETTINGS[$KEY]}"
    LINE="${KEY} = ${VALUE}"

    if grep -Fxq "$LINE" "$CONF_FILE"; then
        echo "Line already set: $LINE"
    elif grep -q "^${KEY}" "$CONF_FILE"; then
        sudo sed -i "s|^${KEY}.*|$LINE|" "$CONF_FILE"
        echo "Updated existing $KEY to $VALUE"
    else
        echo "$LINE" | sudo tee -a "$CONF_FILE" > /dev/null
        echo "Appended: $LINE"
    fi
done


#!/bin/bash

CONF_FILE="/etc/sysctl.d/60-netipv6_sysctl.conf"
declare -A SETTINGS=(
    ["net.ipv6.conf.all.accept_source_route"]="0"
    ["net.ipv6.conf.default.accept_source_route"]="0"
)

for KEY in "${!SETTINGS[@]}"; do
    VALUE="${SETTINGS[$KEY]}"
    LINE="${KEY} = ${VALUE}"

    if grep -Fxq "$LINE" "$CONF_FILE"; then
        echo "Line already set: $LINE"
    elif grep -q "^${KEY}" "$CONF_FILE"; then
        sudo sed -i "s|^${KEY}.*|$LINE|" "$CONF_FILE"
        echo "Updated existing $KEY to $VALUE"
    else
        echo "$LINE" | sudo tee -a "$CONF_FILE" > /dev/null
        echo "Appended: $LINE"
    fi
done


#!/bin/bash

CONF_FILE="/etc/sysctl.d/60-netipv4_sysctl.conf"
declare -A SETTINGS=(
    ["net.ipv4.conf.all.rp_filter"]="1"
    ["net.ipv4.conf.default.rp_filter"]="1"
)

for KEY in "${!SETTINGS[@]}"; do
    VALUE="${SETTINGS[$KEY]}"
    LINE="${KEY} = ${VALUE}"

    if grep -Fxq "$LINE" "$CONF_FILE"; then
        echo "Line already set: $LINE"
    elif grep -q "^${KEY}" "$CONF_FILE"; then
        sudo sed -i "s|^${KEY}.*|$LINE|" "$CONF_FILE"
        echo "Updated: $KEY"
    else
        echo "$LINE" | sudo tee -a "$CONF_FILE" > /dev/null
        echo "Appended: $LINE"
    fi
done

#!/bin/bash

declare -a CRON_DIRS=(
    "/etc/cron.hourly"
    "/etc/cron.daily"
    "/etc/cron.weekly"
    "/etc/cron.monthly"
    "/etc/cron.d"
)

for DIR in "${CRON_DIRS[@]}"; do
    # Ensure the directory exists
    if [ ! -d "$DIR" ]; then
        echo "Directory $DIR does not exist. Skipping."
        continue
    fi

    # Check and set ownership
    OWNER_GROUP=$(stat -c "%U:%G" "$DIR")
    if [ "$OWNER_GROUP" != "root:root" ]; then
        chown root:root "$DIR"
        echo "Ownership of $DIR set to root:root"
    else
        echo "Ownership of $DIR is already root:root"
    fi

    # Check and set permissions
    PERMS=$(stat -c "%a" "$DIR")
    if [ "$PERMS" != "700" ] && [ "$PERMS" != "750" ]; then
        chmod og-rwx "$DIR"
        echo "Permissions of $DIR set to og-rwx (700)"
    else
        echo "Permissions of $DIR already secure: $PERMS"
    fi
done

#!/bin/bash

FILE_PATH="/etc/pam.d/system-auth"

EXPECTED_CONTENT=$(cat <<'EOF'
auth        required                                     pam_env.so
auth        required                                     pam_faildelay.so delay=2000000
auth        [default=1 ignore=ignore success=ok]         pam_usertype.so isregular
auth        [default=1 ignore=ignore success=ok]         pam_localuser.so
auth        sufficient                                   pam_unix.so
auth        [default=1 ignore=ignore success=ok]         pam_usertype.so isregular
auth        sufficient                                   pam_sss.so forward_pass
auth        required                                     pam_deny.so
auth        required                                     pam_faillock.so preauth
auth        required                                     pam_faillock.so authfail

account     required                                     pam_unix.so
account     sufficient                                   pam_localuser.so
account     sufficient                                   pam_usertype.so issystem
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required                                     pam_permit.so
account     required                                     pam_faillock.so

password    requisite                                    pam_pwquality.so local_users_only
password    sufficient                                   pam_unix.so sha512 shadow try_first_pass use_authtok remember=10
password    sufficient                                   pam_sss.so use_authtok
password    required                                     pam_deny.so
password    required                                     pam_pwhistory.so use_authtok

session     optional                                     pam_keyinit.so revoke
session     required                                     pam_limits.so
-session    optional                                     pam_systemd.so
session     [success=1 default=ignore]                   pam_succeed_if.so service in crond quiet use_uid
session     required                                     pam_unix.so
session     optional                                     pam_sss.so
EOF
)

EXPECTED_HASH=$(echo "$EXPECTED_CONTENT" | sha256sum | awk '{print $1}')
CURRENT_HASH=$(sha256sum "$FILE_PATH" 2>/dev/null | awk '{print $1}')

if [[ "$EXPECTED_HASH" != "$CURRENT_HASH" ]]; then
    cp "$FILE_PATH" "$FILE_PATH.bak"
    echo "$EXPECTED_CONTENT" > "$FILE_PATH"
    echo "Updated $FILE_PATH with the new PAM settings. Backup saved as $FILE_PATH.bak"
else
    echo "$FILE_PATH is already correctly configured. No changes made."
fi


#!/bin/bash

FILE_PATH="/etc/pam.d/password-auth"

EXPECTED_CONTENT=$(cat <<'EOF'
auth        required                                     pam_env.so
auth        required                                     pam_faildelay.so delay=2000000
auth        [default=1 ignore=ignore success=ok]         pam_usertype.so isregular
auth        [default=1 ignore=ignore success=ok]         pam_localuser.so
auth        sufficient                                   pam_unix.so
auth        [default=1 ignore=ignore success=ok]         pam_usertype.so isregular
auth        sufficient                                   pam_sss.so forward_pass
auth        required                                     pam_deny.so
auth        required                                     pam_faillock.so preauth
auth        required                                     pam_faillock.so authfail

account     required                                     pam_unix.so
account     sufficient                                   pam_localuser.so
account     sufficient                                   pam_usertype.so issystem
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required                                     pam_permit.so
account     required                                     pam_faillock.so

password    requisite                                    pam_pwquality.so local_users_only
password    sufficient                                   pam_unix.so sha512 shadow
password    sufficient                                   pam_sss.so use_authtok
password    required                                     pam_deny.so
password    required                                     pam_pwhistory.so use_authtok

session     optional                                     pam_keyinit.so revoke
session     required                                     pam_limits.so
-session    optional                                     pam_systemd.so
session     [success=1 default=ignore]                   pam_succeed_if.so service in crond quiet use_uid
session     required                                     pam_unix.so
session     optional                                     pam_sss.so
EOF
)

EXPECTED_HASH=$(echo "$EXPECTED_CONTENT" | sha256sum | awk '{print $1}')
CURRENT_HASH=$(sha256sum "$FILE_PATH" 2>/dev/null | awk '{print $1}')

if [[ "$EXPECTED_HASH" != "$CURRENT_HASH" ]]; then
    cp "$FILE_PATH" "$FILE_PATH.bak"
    echo "$EXPECTED_CONTENT" > "$FILE_PATH"
    echo "Updated $FILE_PATH with new PAM settings. Backup saved as $FILE_PATH.bak"
else
    echo "$FILE_PATH is already correctly configured. No changes made."
fi


#!/bin/bash

FILE_PATH="/etc/security/faillock.conf"
BACKUP_PATH="${FILE_PATH}.bak"
CHANGED=false

# Backup the original file if backup doesn't already exist
if [ ! -f "$BACKUP_PATH" ]; then
    cp "$FILE_PATH" "$BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH"
fi

# Set or update 'deny = 5'
if grep -Eq "^\s*deny\s*=\s*5" "$FILE_PATH"; then
    echo "'deny = 5' already set."
else
    if grep -Eq "^\s*#?\s*deny\s*=" "$FILE_PATH"; then
        sed -i 's/^\s*#\?\s*deny\s*=.*/deny = 5/' "$FILE_PATH"
    else
        echo "deny = 5" >> "$FILE_PATH"
    fi
    echo "Updated or added 'deny = 5'"
    CHANGED=true
fi

# Set or update 'unlock_time = 900'
if grep -Eq "^\s*unlock_time\s*=\s*900" "$FILE_PATH"; then
    echo "'unlock_time = 900' already set."
else
    if grep -Eq "^\s*#?\s*unlock_time\s*=" "$FILE_PATH"; then
        sed -i 's/^\s*#\?\s*unlock_time\s*=.*/unlock_time = 900/' "$FILE_PATH"
    else
        echo "unlock_time = 900" >> "$FILE_PATH"
    fi
    echo "Updated or added 'unlock_time = 900'"
    CHANGED=true
fi

# Ensure 'even_deny_root' is present and uncommented
if grep -Eq "^\s*even_deny_root" "$FILE_PATH"; then
    echo "'even_deny_root' already set."
else
    if grep -Eq "^\s*#\s*even_deny_root" "$FILE_PATH"; then
        sed -i 's/^\s*#\s*even_deny_root/even_deny_root/' "$FILE_PATH"
    else
        echo "even_deny_root" >> "$FILE_PATH"
    fi
    echo "Updated or added 'even_deny_root'"
    CHANGED=true
fi

# Summary
if [ "$CHANGED" = false ]; then
    echo "No changes were made to $FILE_PATH."
fi

# Final preview
echo "Final relevant content in $FILE_PATH:"
grep -E "^\s*(deny|unlock_time|even_deny_root)" "$FILE_PATH"

#!/bin/bash

# 4.4.3.2.1 Ensure password number of changed characters is configured

FILE_PATH="/etc/security/pwquality.conf"
BACKUP_PATH="${FILE_PATH}.bak"
CHANGED=false

# Create a backup
if [ ! -f "$BACKUP_PATH" ]; then
    sudo cp "$FILE_PATH" "$BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH"
fi

# Define settings and values
declare -A SETTINGS=(
    ["minlen"]="14"
    ["difok"]="2"
    ["maxrepeat"]="3"
    ["maxsequence"]="3"
)

# Enforce settings
for KEY in "${!SETTINGS[@]}"; do
    VALUE="${SETTINGS[$KEY]}"
    if grep -Eq "^\s*${KEY}\s*=\s*${VALUE}" "$FILE_PATH"; then
        echo "'$KEY = $VALUE' already set."
    elif grep -Eq "^\s*#?\s*${KEY}\s*=" "$FILE_PATH"; then
        sudo sed -i "s|^\s*#\?\s*${KEY}\s*=.*|${KEY} = ${VALUE}|" "$FILE_PATH"
        echo "Updated '${KEY}' to '${VALUE}'"
        CHANGED=true
    else
        echo "${KEY} = ${VALUE}" | sudo tee -a "$FILE_PATH" > /dev/null
        echo "Added '${KEY} = ${VALUE}'"
        CHANGED=true
    fi
done

# Handle enforce_for_root separately (no value)
if grep -Eq "^\s*enforce_for_root" "$FILE_PATH"; then
    echo "'enforce_for_root' already set."
elif grep -Eq "^\s*#\s*enforce_for_root" "$FILE_PATH"; then
    sudo sed -i 's|^\s*#\s*enforce_for_root|enforce_for_root|' "$FILE_PATH"
    echo "Uncommented 'enforce_for_root'"
    CHANGED=true
else
    echo "enforce_for_root" | sudo tee -a "$FILE_PATH" > /dev/null
    echo "Added 'enforce_for_root'"
    CHANGED=true
fi

# Summary
if [ "$CHANGED" = false ]; then
    echo "No changes were made to $FILE_PATH."
fi

# Final result
echo "Verifying settings in $FILE_PATH:"
grep -E "^(minlen|difok|maxrepeat|maxsequence|enforce_for_root)" "$FILE_PATH"



#!/bin/bash

CONFIG_FILE="/etc/systemd/journald.conf"

declare -A SETTINGS=(
    ["SystemMaxUse"]="1G"
    ["SystemKeepFree"]="500M"
    ["RuntimeMaxUse"]="200M"
    ["RuntimeKeepFree"]="50M"
    ["MaxFileSec"]="1month"
    ["ForwardToSyslog"]="yes"
    ["Compress"]="yes"
    ["Storage"]="persistent"
)

# Backup the config file
if [ -f "$CONFIG_FILE" ]; then
    sudo cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    echo "🔄 Backup created: $CONFIG_FILE.bak"
fi

changes_made=0

for key in "${!SETTINGS[@]}"; do
    value="${SETTINGS[$key]}"

    # Remove commented lines
    sudo sed -i "/^#\s*${key}\s*=.*/d" "$CONFIG_FILE"

    # If key exists but wrong value
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        if ! grep -q "^${key}=${value}$" "$CONFIG_FILE"; then
            sudo sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
            echo "✔ Updated $key to $value"
            ((changes_made++))
        else
            echo "✅ $key already set to $value. Skipping..."
        fi
    else
        # Key doesn't exist; append
        echo "${key}=${value}" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "➕ Added $key=${value}"
        ((changes_made++))
    fi
done

if [ "$changes_made" -eq 0 ]; then
    echo "✅ All journald settings are already correctly set. No changes made."
else
    echo -e "\n🔧 Changes applied. To activate them, run:"
    echo "    sudo systemctl restart systemd-journald"
fi

#!/bin/bash

CONFIG_FILE="/etc/rsyslog.conf"
SETTING_LINE='$FileCreateMode 0640'

# Backup before changes
if [ -f "$CONFIG_FILE" ]; then
    sudo cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    echo "🔄 Backup created at $CONFIG_FILE.bak"
else
    echo "❌ Config file $CONFIG_FILE not found."
    exit 1
fi

# Remove any commented or misconfigured lines
sudo sed -i '/^\s*#\s*\$FileCreateMode\s\+/d' "$CONFIG_FILE"
sudo sed -i '/^\s*\$FileCreateMode\s\+/d' "$CONFIG_FILE"

# Check if the correct line exists
if grep -qF "$SETTING_LINE" "$CONFIG_FILE"; then
    echo "✅ $SETTING_LINE already set. No changes made."
else
    echo "$SETTING_LINE" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "➕ Added $SETTING_LINE to $CONFIG_FILE"
fi


#!/bin/bash

TARGET_LINES=(
    "*.emerg :omusrmsg:*"
    "auth,authpriv.* /var/log/secure"
    "mail.* -/var/log/mail"
    "mail.info -/var/log/mail.info"
    "mail.warning -/var/log/mail.warn"
    "mail.err /var/log/mail.err"
    "cron.* /var/log/cron"
    "*.=warning;*.=err -/var/log/warn"
    "*.crit /var/log/warn"
    "*.*;mail.none;news.none -/var/log/messages"
    "local0,local1.* -/var/log/localmessages"
    "local2,local3.* -/var/log/localmessages"
    "local4,local5.* -/var/log/localmessages"
    "local6,local7.* -/var/log/localmessages"
)

FILES_TO_CHECK=("/etc/rsyslog.conf" /etc/rsyslog.d/*.conf)

for FILE in "${FILES_TO_CHECK[@]}"; do
    [ -f "$FILE" ] || continue

    echo "Checking $FILE..."
    BACKUP="$FILE.bak"
    [ ! -f "$BACKUP" ] && sudo cp "$FILE" "$BACKUP"

    for LINE in "${TARGET_LINES[@]}"; do
        # Escape special characters for grep/sed
        GREP_LINE=$(echo "$LINE" | sed 's/[]\/$*.^|[]/\\&/g')

        if grep -qE "^\s*#\s*$GREP_LINE" "$FILE"; then
            echo "Uncommenting and setting: $LINE"
            sudo sed -i "s|^\s*#\s*$GREP_LINE.*|$LINE|" "$FILE"
        elif grep -qE "^\s*$GREP_LINE" "$FILE"; then
            echo "Line exists and is set: $LINE"
        else
            echo "Adding missing line: $LINE"
            echo "$LINE" | sudo tee -a "$FILE" > /dev/null
        fi
    done
done

echo "✅ Rsyslog configuration check and update complete."


#!/bin/bash

# Settings to enforce
declare -A TARGET_SETTINGS=(
    ["weekly"]=""
    ["rotate"]="4"
    ["compress"]=""
    ["missingok"]=""
    ["notifempty"]=""
)

# Function to update a logrotate configuration file
update_logrotate_file() {
    local file="$1"
    echo "🔧 Processing: $file"

    for key in "${!TARGET_SETTINGS[@]}"; do
        value="${TARGET_SETTINGS[$key]}"

        # Full directive we want to enforce
        desired_line="$key"
        [[ -n "$value" ]] && desired_line="$key $value"

        # Remove commented or incorrect versions
        sudo sed -i "/^\s*#\s*${key}\b.*$/d" "$file"
        sudo sed -i "/^\s*${key}\b.*$/d" "$file"

        # Append only if not already present
        if ! grep -q -E "^\s*${desired_line}$" "$file"; then
            echo "$desired_line" | sudo tee -a "$file" > /dev/null
            echo "➕ Set: $desired_line"
        else
            echo "✅ Already set: $desired_line"
        fi
    done
}

# Update /etc/logrotate.conf
[ -f /etc/logrotate.conf ] && update_logrotate_file "/etc/logrotate.conf"

# Update all files in /etc/logrotate.d/
for conf in /etc/logrotate.d/*; do
    [ -f "$conf" ] && update_logrotate_file "$conf"
done

echo -e "\n✅ All logrotate settings applied without duplication."


#!/usr/bin/env bash

# Script to audit and fix ownership and permissions on /var/log files
# Ensures changes are only applied once; if already correct, it will skip and report as such

l_output2=""
l_uidmin="$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"

file_test_fix() {
    l_op2=""
    l_fuser="root"
    l_fgroup="root"

    # Check file permissions
    if [ $(( l_mode & perm_mask )) -gt 0 ]; then
        l_op2+="\n - Mode: \"$l_mode\" should be \"$maxperm\" or more restrictive\n - Fixing to $l_rperms"
        chmod "$l_rperms" "$l_fname"
    fi

    # Check file owner
    if [[ ! "$l_user" =~ $l_auser ]]; then
        l_op2+="\n - Owner: \"$l_user\" should be \"${l_auser//|/ or }\"\n - Changing to root"
        chown "$l_fuser" "$l_fname"
    fi

    # Check file group
    if [[ ! "$l_group" =~ $l_agroup ]]; then
        l_op2+="\n - Group: \"$l_group\" should be \"${l_agroup//|/ or }\"\n - Changing to root"
        chgrp "$l_fgroup" "$l_fname"
    fi

    # Report result
    if [ -n "$l_op2" ]; then
        l_output2+="\n - File: \"$l_fname\"$l_op2"
    fi
}

# Build file list needing potential remediation
a_file=()
while IFS= read -r -d $'\0' l_file; do
    [ -e "$l_file" ] && a_file+=("$(stat -Lc '%n^%#a^%U^%u^%G^%g' "$l_file")")
done < <(find -L /var/log -type f \( -perm /0137 -o ! -user root -o ! -group root \) -print0)

# Evaluate each file
for entry in "${a_file[@]}"; do
    IFS="^" read -r l_fname l_mode l_user l_uid l_group l_gid <<< "$entry"
    l_bname="$(basename "$l_fname")"

    case "$l_bname" in
        lastlog*|wtmp*|btmp*|README)
            perm_mask='0113'; maxperm=$(printf '%o' $(( 0777 & ~$perm_mask ))); l_rperms="ug-x,o-wx"; l_auser="root"; l_agroup="(root|utmp)"
            ;;
        secure|auth.log|syslog|messages)
            perm_mask='0137'; maxperm=$(printf '%o' $(( 0777 & ~$perm_mask ))); l_rperms="u-x,g-wx,o-rwx"; l_auser="(root|syslog)"; l_agroup="(root|adm)"
            ;;
        SSSD|sssd)
            perm_mask='0117'; maxperm=$(printf '%o' $(( 0777 & ~$perm_mask ))); l_rperms="ug-x,o-rwx"; l_auser="(root|SSSD)"; l_agroup="(root|SSSD)"
            ;;
        gdm|gdm3)
            perm_mask='0117'; maxperm=$(printf '%o' $(( 0777 & ~$perm_mask ))); l_rperms="ug-x,o-rwx"; l_auser="root"; l_agroup="(root|gdm|gdm3)"
            ;;
        *.journal*)
            perm_mask='0137'; maxperm=$(printf '%o' $(( 0777 & ~$perm_mask ))); l_rperms="u-x,g-wx,o-rwx"; l_auser="root"; l_agroup="(root|systemd-journal)"
            ;;
        *)
            perm_mask='0137'; maxperm=$(printf '%o' $(( 0777 & ~$perm_mask ))); l_rperms="u-x,g-wx,o-rwx"; l_auser="(root|syslog)"; l_agroup="(root|adm)"

            if [ "$l_uid" -lt "$l_uidmin" ] && [ -z "$(awk -v grp="$l_group" -F: '$1==grp {print $4}' /etc/group)" ]; then
                [[ ! "$l_user" =~ $l_auser ]] && l_auser="(root|syslog|$l_user)"
                if [[ ! "$l_group" =~ $l_agroup ]]; then
                    l_tst=""
                    while read -r l_duid; do
                        [ "$l_duid" -ge "$l_uidmin" ] && l_tst=failed
                    done <<< "$(awk -F: -v gid="$l_gid" '$4==gid {print $3}' /etc/passwd)"
                    [ "$l_tst" != "failed" ] && l_agroup="(root|adm|$l_group)"
                fi
            fi
            ;;
    esac

    file_test_fix

done

# Final output
if [ -z "$l_output2" ]; then
    echo -e "\n✅ All /var/log files are correctly configured. No changes made."
else
    echo -e "\n🛠️  Remediation Summary:$l_output2"
fi

#!/bin/bash

# Target rsyslog forwarding configuration
FORWARDING_RULE='*.* action(type="omfwd" target="loghost.example.com" port="514" protocol="tcp" action.resumeRetryCount="100" queue.type="LinkedList" queue.size="1000")'

# Files to check and edit
FILES=("/etc/rsyslog.conf" /etc/rsyslog.d/*.conf)

# Flag to track if rule already exists
RULE_EXISTS=false

# Loop through each file to check for existing rule
for FILE in "${FILES[@]}"; do
    if grep -Fxq "$FORWARDING_RULE" "$FILE"; then
        echo "✅ Rule already exists in $FILE"
        RULE_EXISTS=true
        break
    fi
done

# If rule doesn't exist, append to /etc/rsyslog.conf
if ! $RULE_EXISTS; then
    echo -e "\n$FORWARDING_RULE" | sudo tee -a /etc/rsyslog.conf > /dev/null
    echo "✅ Rule added to /etc/rsyslog.conf"
else
    echo "ℹ️  No changes made. Forwarding rule already configured."
fi


grubby --update-kernel ALL --args 'audit_backlog_limit=8192'


#!/bin/bash

CONFIG_FILE="/etc/audit/auditd.conf"
KEY="max_log_file_action"
VALUE="keep_logs"
LINE="$KEY = $VALUE"

# Backup original
if [ -f "$CONFIG_FILE" ]; then
    sudo cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    echo "🧾 Backup created: $CONFIG_FILE.bak"
else
    echo "❌ File not found: $CONFIG_FILE"
    exit 1
fi

# Check if correctly set
if grep -Eq "^\s*${KEY}\s*=\s*${VALUE}" "$CONFIG_FILE"; then
    echo "✅ $KEY is already set to '$VALUE'. No changes made."
else
    # Remove commented or misconfigured lines
    sudo sed -i "/^\s*#\?\s*${KEY}\s*=.*/d" "$CONFIG_FILE"

    # Add the correct setting
    echo "$LINE" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "✅ Set $KEY to '$VALUE' in $CONFIG_FILE"
fi





#!/bin/bash

FILE="/etc/profile.d/50-tmout.sh"
EXPECTED_CONTENT=$'# Set TMOUT to 900 seconds\ntypeset -xr TMOUT=900'

# Check if the file exists and content matches
if [ -f "$FILE" ]; then
    CURRENT_CONTENT=$(< "$FILE")
    if [[ "$CURRENT_CONTENT" == "$EXPECTED_CONTENT" ]]; then
        echo "✅ TMOUT setting already configured in $FILE. No changes made."
        exit 0
    else
        echo "⚠️  $FILE exists but content differs. Updating..."
    fi
else
    echo "ℹ️  $FILE does not exist. Creating..."
fi

# Write the correct content
echo "$EXPECTED_CONTENT" | sudo tee "$FILE" > /dev/null
echo "✅ TMOUT setting applied to $FILE"



#!/bin/bash

# 4.4.3.3.1 Ensure password history remember is configured

FILE_PATH="/etc/security/pwhistory.conf"
BACKUP_PATH="${FILE_PATH}.bak"
CHANGED=false

# Backup if not already done
if [ ! -f "$BACKUP_PATH" ]; then
    sudo cp "$FILE_PATH" "$BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH"
fi

# Ensure the file exists
sudo touch "$FILE_PATH"

# Handle 'remember = 24'
if grep -Eq "^\s*#?\s*remember\s*=" "$FILE_PATH"; then
    sudo sed -i 's/^\s*#\?\s*remember\s*=.*/remember = 24/' "$FILE_PATH"
    echo "Set 'remember = 24'"
    CHANGED=true
else
    echo "remember = 24" | sudo tee -a "$FILE_PATH" > /dev/null
    echo "Added 'remember = 24'"
    CHANGED=true
fi

# Handle 'enforce_for_root'
if grep -Eq "^\s*#?\s*enforce_for_root" "$FILE_PATH"; then
    sudo sed -i 's/^\s*#\?\s*enforce_for_root.*/enforce_for_root/' "$FILE_PATH"
    echo "Ensured 'enforce_for_root' is uncommented"
    CHANGED=true
else
    echo "enforce_for_root" | sudo tee -a "$FILE_PATH" > /dev/null
    echo "Added 'enforce_for_root'"
    CHANGED=true
fi

# Summary
if [ "$CHANGED" = false ]; then
    echo "No changes were made to $FILE_PATH."
fi

# Display final content
echo "Final content of $FILE_PATH:"
cat "$FILE_PATH"


#!/bin/bash

# Define the file path
FILE_PATH="/etc/login.defs"
UMASK_VALUE="027"
CHANGED=false

# Check and set UMASK value
if grep -qE "^\s*UMASK\s+$UMASK_VALUE" "$FILE_PATH"; then
    echo "UMASK is already set to $UMASK_VALUE in $FILE_PATH. No changes made."
else
    if grep -qE "^\s*UMASK\s+" "$FILE_PATH"; then
        sudo sed -i "s|^\s*UMASK\s\+.*|UMASK           $UMASK_VALUE|" "$FILE_PATH"
        echo "UMASK updated to $UMASK_VALUE in $FILE_PATH."
    else
        echo "UMASK           $UMASK_VALUE" | sudo tee -a "$FILE_PATH" > /dev/null
        echo "UMASK added to $FILE_PATH."
    fi
    CHANGED=true
fi

# Verify the changes
echo "Verifying changes in $FILE_PATH..."
grep -E "^(PASS_MAX_DAYS|UMASK)" "$FILE_PATH"

# Apply 'audit=1' to GRUB if not already present
if grubby --info=ALL | grep -q 'audit=1'; then
    echo "'audit=1' already set in GRUB kernel arguments. Skipping."
else
    grubby --update-kernel=ALL --args 'audit=1'
    echo "'audit=1' has been appended to all GRUB kernel entries."
    CHANGED=true
fi

# Summary
if [ "$CHANGED" = false ]; then
    echo "No changes were made."
fi


#!/bin/bash

# Define the file path
FILE_PATH="/etc/audit/auditd.conf"
CHANGED=false

# Backup the original file (optional but recommended)
sudo cp "$FILE_PATH" "$FILE_PATH.bak"

declare -A CONFIGS=(
    ["max_log_file"]="32"
    ["disk_full_action"]="halt"
    ["disk_error_action"]="halt"
    ["space_left_action"]="email"
    ["admin_space_left_action"]="single"
)

for KEY in "${!CONFIGS[@]}"; do
    VALUE="${CONFIGS[$KEY]}"

    if grep -qE "^$KEY\s*=\s*$VALUE" "$FILE_PATH"; then
        echo "$KEY is already set to $VALUE. Skipping."
    elif grep -qE "^$KEY\s*=" "$FILE_PATH"; then
        sudo sed -i "s|^$KEY\s*=.*|$KEY = $VALUE|" "$FILE_PATH"
        echo "$KEY updated to $VALUE."
        CHANGED=true
    else
        echo "$KEY = $VALUE" | sudo tee -a "$FILE_PATH" > /dev/null
        echo "$KEY added with value $VALUE."
        CHANGED=true
    fi
done

# Verification
echo "Verifying changes in $FILE_PATH..."
grep -E "^(max_log_file|disk_full_action|disk_error_action|space_left_action|admin_space_left_action)" "$FILE_PATH"

if [ "$CHANGED" = false ]; then
    echo "All settings already configured. No changes made."
fi


#!/bin/bash

FILE="/etc/crypto-policies/policies/modules/NO-SSHETM.pmod"
LINES=(
    "# This is a subpolicy to disable Encrypt then MAC"
    "# for the SSH protocol (libssh and OpenSSH)"
    "etm@SSH = DISABLE_ETM"
)

CHANGED=false

# Create file if it doesn't exist
if [ ! -f "$FILE" ]; then
    touch "$FILE"
    echo "Created file: $FILE"
    CHANGED=true
fi

# Append lines only if not already present
for LINE in "${LINES[@]}"; do
    if ! grep -Fxq "$LINE" "$FILE"; then
        echo "$LINE" | sudo tee -a "$FILE" > /dev/null
        echo "Added: $LINE"
        CHANGED=true
    fi
done

# Final status
if [ "$CHANGED" = false ]; then
    echo "All lines already exist in $FILE. No changes made."
else
    echo "Update complete. Current content of $FILE:"
    cat "$FILE"
fi

#!/bin/bash

FILE="/etc/crypto-policies/policies/modules/NO-SSHWEAKCIPHERS.pmod"
LINES=(
    "# This is a subpolicy to disable weak ciphers"
    "# for the SSH protocol (libssh and OpenSSH)"
    "cipher@SSH = -3DES-CBC -AES-128-CBC -AES-192-CBC -AES-256-CBC -CHACHA20-POLY1305"
)

CHANGED=false

# Create file if it doesn't exist
if [ ! -f "$FILE" ]; then
    sudo touch "$FILE"
    echo "Created file: $FILE"
    CHANGED=true
fi

# Append lines only if not already present
for LINE in "${LINES[@]}"; do
    if ! grep -Fxq "$LINE" "$FILE"; then
        echo "$LINE" | sudo tee -a "$FILE" > /dev/null
        echo "Added: $LINE"
        CHANGED=true
    fi
done

# Final status
if [ "$CHANGED" = false ]; then
    echo "All lines already exist in $FILE. No changes made."
else
    echo "Update complete. Current content of $FILE:"
    cat "$FILE"
fi


#!/bin/bash

# 5.2.12 Ensure SSH X11Forwarding is disabled

FILE_PATH="/etc/ssh/sshd_config"
KEY="X11Forwarding"
VALUE="no"
TARGET_LINE="$KEY $VALUE"

# Backup
if [ -f "$FILE_PATH" ]; then
    sudo cp "$FILE_PATH" "$FILE_PATH.bak"
    echo "Backup created: $FILE_PATH.bak"
else
    echo "File $FILE_PATH does not exist. Exiting."
    exit 1
fi

# Check if the correct setting already exists
if grep -q "^${KEY}[[:space:]]\+${VALUE}" "$FILE_PATH"; then
    echo "$KEY is already set to $VALUE. No changes made."
else
    # If line exists with different value or commented, replace it
    if grep -q "^[#]*\s*${KEY}" "$FILE_PATH"; then
        sudo sed -i "s|^[#]*\s*${KEY}.*|${TARGET_LINE}|" "$FILE_PATH"
        echo "Updated: $KEY set to $VALUE"
    else
        echo "$TARGET_LINE" | sudo tee -a "$FILE_PATH" > /dev/null
        echo "Appended: $KEY set to $VALUE"
    fi
fi

echo "Script execution complete."


#!/bin/bash

# 5.2.13 Ensure SSH AllowTcpForwarding is disabled

FILE_PATH="/etc/ssh/sshd_config"
KEY="AllowTcpForwarding"
VALUE="no"
TARGET_LINE="$KEY $VALUE"

# Backup the original file
if [ -f "$FILE_PATH" ]; then
    sudo cp "$FILE_PATH" "$FILE_PATH.bak"
    echo "Backup created: $FILE_PATH.bak"
else
    echo "File $FILE_PATH does not exist. Exiting."
    exit 1
fi

# Check if already set correctly
if grep -q "^$KEY[[:space:]]\+$VALUE" "$FILE_PATH"; then
    echo "$KEY is already set to $VALUE. No changes made."
else
    # Replace commented or wrong value line
    if grep -q "^[#]*[[:space:]]*$KEY" "$FILE_PATH"; then
        sudo sed -i "s|^[#]*[[:space:]]*$KEY.*|$TARGET_LINE|" "$FILE_PATH"
        echo "Updated: $TARGET_LINE"
    else
        echo "$TARGET_LINE" | sudo tee -a "$FILE_PATH" > /dev/null
        echo "Appended: $TARGET_LINE"
    fi
fi

echo "Script execution complete."


#!/bin/bash

create_or_verify_repo_file() {
    local FILE_PATH="$1"
    local TYPE="$2"
    local BASEURL="$3"
    local APPSTREAM_URL="$4"

    local CONTENT=$(cat <<EOF
[InstallMedia-BaseOS]
name = Redhat-Enterprice-Linux 9-Server-BaseOS-rpms
baseurl = $BASEURL
gpgcheck = 0
enabled = 1

[InstallMedia-Appstream]
name = Redhat-Enterprice-Linux 9-Server-Appstream-rpms
baseurl = $APPSTREAM_URL
gpgcheck = 0
enabled = 1
EOF
)

    if [ -f "$FILE_PATH" ]; then
        if diff <(echo "$CONTENT") "$FILE_PATH" > /dev/null; then
            echo "$TYPE repo already configured. No changes made to $FILE_PATH."
        else
            echo "$TYPE repo exists but content differs. Updating $FILE_PATH..."
            echo "$CONTENT" | sudo tee "$FILE_PATH" > /dev/null
            echo "$FILE_PATH updated successfully."
        fi
    else
        echo "$TYPE repo does not exist. Creating $FILE_PATH..."
        echo "$CONTENT" | sudo tee "$FILE_PATH" > /dev/null
        echo "$FILE_PATH created successfully."
    fi
}

# Define Local CDN paths
LOCAL_FILE="/etc/yum.repos.d/localcdn.repo"
LOCAL_BASEURL="file:///var/rhel9repo/rhel-9-for-x86_64-baseos-rpms"
LOCAL_APPSTREAM_URL="file:///var/rhel9repo/rhel-9-for-x86_64-appstream-rpms"

# Define Remote CDN paths
REMOTE_FILE="/etc/yum.repos.d/remotecdn.repo"
REMOTE_BASEURL="http://xxx.xxx.xxx.xxx/rhel9repo/rhel-9-for-x86_64-baseos-rpms"
REMOTE_APPSTREAM_URL="http://xxx.xxx.xxx.xxx/rhel9repo/rhel-9-for-x86_64-appstream-rpms"

# Create or verify both repo files
create_or_verify_repo_file "$LOCAL_FILE" "Local CDN" "$LOCAL_BASEURL" "$LOCAL_APPSTREAM_URL"
create_or_verify_repo_file "$REMOTE_FILE" "Remote CDN" "$REMOTE_BASEURL" "$REMOTE_APPSTREAM_URL"


#!/bin/bash

# Define the file path and expected content
FILE_PATH="/etc/chrony.conf"
CHRONY_SERVER="server xxx.xx.xx.xx iburst"
CHRONY_OPTIONS="OPTIONS='-u chrony'"

# Check if chrony is installed
if ! rpm -q chrony &>/dev/null; then
    echo -e "\n[!] Chrony is NOT installed."
    echo "You must install it first: sudo dnf install chrony"
    read -rp "Press [Enter] to continue the script anyway..."
else
    echo -e "\n[✔] Chrony is installed. Proceeding with configuration..."

    # Backup existing config
    if [ -f "$FILE_PATH" ]; then
        sudo cp "$FILE_PATH" "$FILE_PATH.bak"
        echo "[+] Backup created at: $FILE_PATH.bak"
    else
        echo "[!] $FILE_PATH does not exist. Creating new file."
        sudo touch "$FILE_PATH"
    fi

    # Add chrony server line if not already present
    if grep -Fxq "$CHRONY_SERVER" "$FILE_PATH"; then
        echo "[=] Server line already exists. Skipping..."
    else
        echo "$CHRONY_SERVER" | sudo tee -a "$FILE_PATH" > /dev/null
        echo "[+] Added server line to $FILE_PATH"
    fi

    # Add options line if not already present
    if grep -Fxq "$CHRONY_OPTIONS" "$FILE_PATH"; then
        echo "[=] Options line already exists. Skipping..."
    else
        sudo sed -i "/$CHRONY_SERVER/a $CHRONY_OPTIONS" "$FILE_PATH"
        echo "[+] Added options line below server line."
    fi
fi

echo -e "\n[✔] Script execution completed."


#!/bin/bash
echo "[*] Fixing permissions for audit config files..."
find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \) -exec chmod 640 {} \;

echo "[*] Verifying permissions..."
result=$(
/bin/find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \) -exec /bin/stat -Lc "%n %a" {} + | \
/bin/grep -Pv -- '^\h*\H+\h*([0,2,4,6][0,4]0)\h*$' | \
/bin/awk '{print} END { if(NR==0) print "pass" ; else print "fail"}'
)
echo "Result: $result"




#!/bin/bash

# Prompt user to continue
read -rp "This script will configure a systemd AIDE check service and timer. Press [Enter] to continue or Ctrl+C to cancel..."

# Check if AIDE is installed
if ! rpm -q aide &>/dev/null; then
    echo "AIDE is not installed. Please install it with 'sudo dnf install aide' and re-run this script."
    exit 1
fi

# Define file paths
SERVICE_FILE="/etc/systemd/system/aidecheck.service"
TIMER_FILE="/etc/systemd/system/aidecheck.timer"

# Expected content for aidecheck.service
read -r -d '' SERVICE_CONTENT << 'EOF'
[Unit]
Description=Aide Check

[Service]
Type=simple
ExecStart=/usr/sbin/aide --check

[Install]
WantedBy=multi-user.target
EOF

# Expected content for aidecheck.timer
read -r -d '' TIMER_CONTENT << 'EOF'
[Unit]
Description=Aide check every day at 5AM

[Timer]
OnCalendar=*-*-* 05:00:00
Unit=aidecheck.service

[Install]
WantedBy=multi-user.target
EOF

# Function to create/update files only if needed
update_file_if_needed() {
    local file_path="$1"
    local expected_content="$2"
    local filename
    filename=$(basename "$file_path")

    if [ -f "$file_path" ]; then
        if diff <(echo "$expected_content") "$file_path" &>/dev/null; then
            echo "$filename is already correctly configured. No changes made."
        else
            echo "$expected_content" | sudo tee "$file_path" > /dev/null
            echo "$filename has been updated with new content."
        fi
    else
        echo "$expected_content" | sudo tee "$file_path" > /dev/null
        echo "$filename has been created with expected content."
    fi
}

# Apply updates
update_file_if_needed "$SERVICE_FILE" "$SERVICE_CONTENT"
update_file_if_needed "$TIMER_FILE" "$TIMER_CONTENT"

# Reload and enable timer
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now aidecheck.timer

# Show status
echo ""
sudo systemctl status aidecheck.timer --no-pager
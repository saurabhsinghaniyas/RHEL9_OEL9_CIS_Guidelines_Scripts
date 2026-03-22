# RHEL9_OEL9_CIS_Guidelines_Scripts
RHEL9_OEL9_CIS_Guidelines_Scripts will be used to build a standard hardened system.
**This script will work the same for Oracle Enterprise Linux 9**
RHEL 9 CIS Benchmark Audit Script
This script performs a comprehensive security audit of Red Hat Enterprise Linux 9 systems based on CIS (Center for Internet Security) Benchmark recommendations. It checks various system configurations, security settings, and provides detailed reports in multiple formats.
Features
Modular Structure: Each CIS section is implemented as a separate function
Multiple Output Formats: Supports CSV, JSON, and text output formats
Idempotent Execution: Tracks completed sections to avoid duplicate runs
Color-Coded Output: Uses color coding for better visibility of results
Detailed Logging: Maintains comprehensive audit logs
Section-wise Execution: Ability to run specific sections independently
Progress Tracking: Shows pass/fail statistics for each check
Usage
```bash
./RHEL9-CIS-Audit.sh [OPTIONS]

Options:
  -s, --section SECTION    Run specific section (1-7)
  -o, --output FORMAT     Output format (text|csv|json)
  -h, --help             Show this help message
  -l, --last             Show last audit report
```
Script Structure
1. Core Functions
Utility Functions
`check_root()`: Verifies script is run as root
`check_file_permissions()`: Validates file ownership and permissions
`log_result()`: Records audit results to CSV file
`mark_section_complete()`: Tracks completed sections
`check_section_status()`: Verifies if section was already audited
2. Section-wise Breakdown
Section 1: Initial Setup
1.1 Filesystem Configuration
`audit_section1_1_1()`: Checks kernel module configurations
`audit_section1_1_2()`: Validates mount options
1.2 Software Updates
`audit_section1_2()`: Package management checks
1.3 Filesystem Integrity
`audit_section1_3()`: SELinux configuration validation
1.4 Secure Boot
`audit_section1_4()`: Bootloader security checks
1.5 Additional Process Hardening
`audit_section1_5()`: Core dumps and prelink checks
1.6 Mandatory Access Control
`audit_section1_6()`: SELinux state verification
1.7 Warning Banners
`audit_section1_7()`: System warning banner configuration
1.8 GNOME Display Manager
`audit_section1_8()`: GNOME security settings
Section 2: Services
Implementation uses service status checks and package presence verification:
```bash
# Example pattern used throughout service checks
systemctl is-enabled service_name &>/dev/null
```
Section 3: Network Configuration
Includes network parameter verification and firewall rules:
```bash
# Common pattern for sysctl checks
sysctl_check() {
    local param="$1"
    local expected="$2"
    current=$(sysctl -n "$param" 2>/dev/null)
}
```
Section 4: Logging and Auditing
Focuses on audit daemon configuration and system logging:
`audit_section4_1()`: auditd configuration
`audit_section4_2()`: System logging configuration
`audit_section4_3()`: Log rotation settings
Section 5: Access, Authentication and Authorization
Handles user accounts, passwords, and SSH configuration:
```bash
# Pattern for PAM configuration checks
check_pam_setting() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$file"
}
```
Section 6: System Maintenance
System file integrity and audit configuration:
`audit_section6_1()`: File integrity checks
`audit_section6_2_x()`: System logging configuration
`audit_section6_3_x()`: Audit configuration
Section 7: System File Permissions
Validates file permissions and ownership:
`audit_section7_1()`: System file permissions
`audit_section7_2()`: User and group settings
3. Reporting Functions
Output Formatting
```bash
show_last_report() {
    # Supports multiple output formats:
    # - Text: Human-readable with color coding
    # - CSV: Comma-separated values
    # - JSON: Machine-readable format
}
```
Implementation Details
Loop Patterns Used
File System Checks
```bash
for mount in ${mount_points[@]}; do
    # Check mount point options
done
```
Service Verification
```bash
for service in ${services[@]}; do
    # Check service status
done
```
Configuration File Validation
```bash
for config_file in ${config_files[@]}; do
    # Validate file contents and permissions
done
```
Error Handling
The script implements comprehensive error handling:
Checks for root privileges
Validates file existence before operations
Handles missing tools and commands
Provides detailed error messages
Status Tracking
Uses `/var/log/cis_audit/` for tracking completed sections
Implements idempotency through status files
Maintains audit history with timestamps
Reports
Output Formats
CSV Format
```csv
Timestamp,Check Name,Status,Details
2025-08-10 10:00:00,1.1.1,PASS,Secure Mount Options Configured
```
JSON Format
```json
[
  {
    "check": "1.1.1",
    "status": "PASS",
    "details": "Secure Mount Options Configured",
    "section": "Initial Setup"
  }
]
```
Text Format
Color-coded output
Hierarchical section display
Detailed pass/fail information
Requirements
Root access
RHEL 9 or compatible system
Basic system utilities (awk, grep, etc.)
Best Practices
Run with root privileges
Review results in detail
Keep audit logs for compliance
Regularly schedule audits
Backup system before remediation

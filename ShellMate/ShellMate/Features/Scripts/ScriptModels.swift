import Foundation

// MARK: - Script 数据模型

struct Script: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var category: String          // 用于左侧分组，如 "Monitoring"
    var content: String
    var isScheduled: Bool = false
    var scheduleDescription: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}

// MARK: - 执行日志条目

struct ScriptLogEntry: Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var output: String
    var isError: Bool = false
}

// MARK: - 预置示例脚本

extension Script {
    static let samples: [Script] = [
        Script(
            name: "System Health Check",
            description: "Check CPU, memory, and disk usage",
            category: "Monitoring",
            content: """
# System Health Check Script
# This script monitors system resources

echo "=== System Health Check ==="
echo ""

echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\\([0-9.]*\\)%* id.*/\\1/" | awk '{print 100 - $1"%"}'

echo ""
echo "Memory Usage:"
free -h | grep Mem | awk '{print "Used: " $3 " / " $2 " (" $3/$2*100 "%)"}'

echo ""
echo "Disk Usage:"
df -h | grep '^/dev/' | awk '{print $6 ": " $5 " used"}'

echo ""
echo "=== Health Check Complete ==="
""",
            isScheduled: false
        ),
        Script(
            name: "Automated Backup",
            description: "Backup important directories with compression",
            category: "Backup",
            content: """
#!/bin/bash
# Automated Backup Script

BACKUP_DIR="/backup"
SOURCE_DIR="/var/www"
DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="backup_${DATE}.tar.gz"

echo "Starting backup..."
mkdir -p $BACKUP_DIR
tar -czf "$BACKUP_DIR/$FILENAME" "$SOURCE_DIR"
echo "Backup saved: $BACKUP_DIR/$FILENAME"
""",
            isScheduled: false
        ),
        Script(
            name: "Database Dump",
            description: "Export database with timestamp",
            category: "Backup",
            content: """
#!/bin/bash
# Database Dump Script

DB_NAME="myapp"
DB_USER="root"
DUMP_DIR="/var/backup/db"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $DUMP_DIR
mysqldump -u $DB_USER $DB_NAME > "$DUMP_DIR/${DB_NAME}_${DATE}.sql"
echo "Database dump completed: ${DB_NAME}_${DATE}.sql"
""",
            isScheduled: false
        ),
        Script(
            name: "Service Restart",
            description: "Restart web services with health check",
            category: "Deployment",
            content: """
#!/bin/bash
# Service Restart Script

services=("nginx" "php-fpm" "mysql")

for service in "${services[@]}"; do
    echo "Restarting $service..."
    systemctl restart $service
    if systemctl is-active --quiet $service; then
        echo "✓ $service is running"
    else
        echo "✗ $service failed to start"
    fi
done
""",
            isScheduled: false
        ),
        Script(
            name: "Log Rotation",
            description: "Rotate and compress old log files",
            category: "Maintenance",
            content: """
#!/bin/bash
# Log Rotation Script

LOG_DIR="/var/log/app"
DAYS_TO_KEEP=7

echo "Rotating logs in $LOG_DIR..."
find $LOG_DIR -name "*.log" -mtime +$DAYS_TO_KEEP -exec gzip {} \\;
find $LOG_DIR -name "*.log.gz" -mtime +30 -delete
echo "Log rotation complete"
""",
            isScheduled: true,
            scheduleDescription: "Scheduled"
        ),
        Script(
            name: "Security Scan",
            description: "Basic security checks and updates",
            category: "Security",
            content: """
#!/bin/bash
# Security Scan Script

echo "=== Security Scan ==="

echo "\\nChecking for failed login attempts:"
grep "Failed password" /var/log/auth.log | tail -20

echo "\\nOpen ports:"
ss -tlnp

echo "\\nPending security updates:"
apt list --upgradable 2>/dev/null | grep -i security

echo "=== Scan Complete ==="
""",
            isScheduled: false
        )
    ]
}

#!/usr/bin/env bash

# Example Backup Configuration
# Source this file in backup scripts or copy settings to backup-manager.sh

# Backup directories
BACKUP_DIRS=(
    "/home"
    "/etc"
    "/var/www"
    "/opt/applications"
)

# Database configurations
DB_MYSQL_ENABLED=true
MYSQL_USER="backup"
MYSQL_PASSWORD="your-password"
MYSQL_DATABASES=("app_db" "wordpress_db")

DB_POSTGRES_ENABLED=true
POSTGRES_USER="postgres"
POSTGRES_DATABASES=("myapp" "analytics")

# Docker volumes to backup
DOCKER_VOLUMES=(
    "wordpress_data"
    "nextcloud_data"
    "grafana_data"
)

# Backup destinations
BACKUP_LOCAL_DIR="/backup/local"
BACKUP_REMOTE_ENABLED=true
BACKUP_REMOTE_HOST="backup-server.example.com"
BACKUP_REMOTE_USER="backup"
BACKUP_REMOTE_DIR="/backup/remote"

# S3 configuration
BACKUP_S3_ENABLED=false
S3_BUCKET="my-backups"
S3_REGION="us-east-1"
AWS_ACCESS_KEY_ID="your-key"
AWS_SECRET_ACCESS_KEY="your-secret"

# Retention policy
RETENTION_DAILY=7
RETENTION_WEEKLY=4
RETENTION_MONTHLY=6

# Notifications
NOTIFY_EMAIL="admin@example.com"
NOTIFY_NTFY_TOPIC="backups"

# Compression
COMPRESSION_LEVEL=6  # 1-9, higher = better compression, slower

# Encryption
ENCRYPT_BACKUPS=true
GPG_RECIPIENT="admin@example.com"

# Runbook: Disk Full

## Overview
Steps to diagnose and resolve disk space issues on Linux servers.

## Severity
**High** - Can cause service outages and data loss

## Symptoms
- "No space left on device" errors
- Applications failing to write files
- Database errors
- System instability

## Immediate Actions

### 1. Check Current Disk Usage
```bash
df -h
```

Identify which filesystem is full (usually `/`, `/var`, `/home`, or `/tmp`).

### 2. Find Large Directories
```bash
# Check top-level directories
sudo du -sh /* | sort -rh | head -10

# For /var specifically
sudo du -sh /var/* | sort -rh | head -10
```

## Common Causes & Solutions

### Docker Taking Too Much Space
```bash
# Check Docker disk usage
docker system df

# Clean up (WARNING: removes unused containers/images)
docker system prune -af --volumes

# Or use the cleanup script
./scripts/docker/docker-cleanup.sh --all --execute
```

### Log Files Growing Too Large
```bash
# Find large log files
find /var/log -type f -size +100M -exec ls -lh {} \;

# Truncate a log file (keeps file descriptor open)
sudo truncate -s 0 /var/log/some-large-file.log

# Or use logrotate immediately
sudo logrotate -f /etc/logrotate.conf

# Clean old logs with our script
sudo ./scripts/disk/cleanup-old-files.sh --execute clean-logs
```

### APT Cache Full
```bash
# Check APT cache size
du -sh /var/cache/apt/archives

# Clean APT cache
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y
```

### Temp Files Accumulating
```bash
# Check /tmp size
du -sh /tmp

# Clean old temp files
sudo find /tmp -type f -atime +7 -delete

# Or use the cleanup script
sudo ./scripts/disk/cleanup-old-files.sh --execute clean-temp
```

### Journal Logs Too Large
```bash
# Check journal size
journalctl --disk-usage

# Vacuum old logs (keep last 7 days)
sudo journalctl --vacuum-time=7d

# Or limit by size (keep last 500MB)
sudo journalctl --vacuum-size=500M
```

### Old Kernels Taking Space
```bash
# List installed kernels
dpkg --list | grep linux-image

# Remove old kernels (keeps current + one previous)
sudo apt-get autoremove --purge
```

### Database Backups Accumulating
```bash
# Find old backup files
find /var/backups -type f -mtime +30 -name "*.sql.gz"

# Remove backups older than 30 days
find /var/backups -type f -mtime +30 -name "*.sql.gz" -delete
```

## Prevention

### 1. Set Up Monitoring
```bash
# Add disk space alerts to health monitoring
# Edit inventory/servers.yaml and configure alerting
./scripts/monitoring/health-check.py --config inventory/servers.yaml
```

### 2. Configure Log Rotation
```bash
# Check logrotate configuration
cat /etc/logrotate.conf

# Add custom log rotation
sudo nano /etc/logrotate.d/custom
```

### 3. Schedule Automated Cleanup
```bash
# Add to crontab for weekly cleanup
crontab -e

# Add this line:
# 0 2 * * 0 /path/to/scripts/disk/cleanup-old-files.sh --execute clean-all
```

### 4. Limit Journal Size
```bash
# Edit journald config
sudo nano /etc/systemd/journald.conf

# Set these values:
SystemMaxUse=500M
SystemMaxFileSize=100M

# Restart journald
sudo systemctl restart systemd-journald
```

## Emergency Measures

### If System is Unresponsive

1. **Free space immediately:**
```bash
# Truncate largest log file
sudo truncate -s 0 /var/log/syslog

# Or delete temp files
sudo rm -rf /tmp/*
```

2. **Restart critical services:**
```bash
sudo systemctl restart nginx
sudo systemctl restart docker
```

## Verification

After cleanup, verify:
```bash
# Check disk space freed
df -h

# Verify services are running
systemctl status nginx
systemctl status docker

# Check application logs for errors
journalctl -u your-service -n 50
```

## Post-Incident

1. Document what caused the issue
2. Implement monitoring if not already in place
3. Set up automated cleanup
4. Review backup retention policies
5. Consider adding more disk space if issue persists

## Related Scripts

- `scripts/disk/cleanup-old-files.sh` - Automated cleanup
- `scripts/monitoring/health-check.py` - Disk space monitoring
- `scripts/alerting/notify.sh` - Send alerts

## Additional Resources

- [Linux disk space management](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html)
- [Docker disk cleanup](https://docs.docker.com/config/pruning/)
- [systemd journal size](https://www.freedesktop.org/software/systemd/man/journald.conf.html)

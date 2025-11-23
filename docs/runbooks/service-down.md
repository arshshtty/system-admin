# Runbook: Service Down

## Overview
Steps to diagnose and restore downed services on Linux servers.

## Severity
**Critical** - Service unavailable to users

## Symptoms
- Service not responding to requests
- HTTP 502/503/504 errors
- Connection timeouts
- Application errors

## Immediate Actions

### 1. Verify Service Status
```bash
# Check systemd service
sudo systemctl status <service-name>

# Check if process is running
ps aux | grep <service-name>

# Check listening ports
sudo netstat -tlnp | grep <port>
# or
sudo ss -tlnp | grep <port>
```

### 2. Quick Restart Attempt
```bash
# Restart the service
sudo systemctl restart <service-name>

# Check status again
sudo systemctl status <service-name>

# Verify it's responding
curl -I http://localhost:<port>
```

If restart succeeds, monitor for stability and proceed to root cause analysis.
If restart fails, continue diagnosis.

## Diagnosis Steps

### Check Service Logs

**Systemd services:**
```bash
# Recent logs
sudo journalctl -u <service-name> -n 100 --no-pager

# Follow logs in real-time
sudo journalctl -u <service-name> -f

# Logs with timestamps
sudo journalctl -u <service-name> --since "10 minutes ago"
```

**Application logs:**
```bash
# Common log locations
sudo tail -n 100 /var/log/<service>/*.log
sudo tail -n 100 /var/log/syslog | grep <service>

# Docker container logs
docker logs <container-name> --tail 100 --timestamps
```

### Common Failure Causes

#### 1. Port Already in Use
```bash
# Check what's using the port
sudo lsof -i :<port>

# Kill the conflicting process if needed
sudo kill <PID>

# Or change the port in service config
```

#### 2. Insufficient Resources

**Memory:**
```bash
# Check memory
free -h

# Check for OOM killer
sudo journalctl -k | grep -i "killed process"

# If OOM occurred, free memory or add more RAM
```

**Disk space:**
```bash
# Check disk space
df -h

# If full, see disk-full.md runbook
```

**File descriptors:**
```bash
# Check current limits
ulimit -n

# Check service limits
sudo systemctl show <service> | grep LimitNOFILE

# Increase if needed
sudo systemctl edit <service>

# Add:
[Service]
LimitNOFILE=65536
```

#### 3. Configuration Errors
```bash
# Test configuration (service-specific)

# Nginx
sudo nginx -t

# Apache
sudo apache2ctl configtest

# PostgreSQL
sudo -u postgres /usr/lib/postgresql/*/bin/postgres --config-file=/etc/postgresql/*/main/postgresql.conf -C

# MySQL
sudo mysqld --help --verbose

# Review recent config changes
sudo find /etc/<service>/ -type f -mtime -1 -ls
```

#### 4. Dependency Failures
```bash
# Check service dependencies
systemctl list-dependencies <service-name>

# Check status of dependencies
systemctl status <dependency-name>

# Start dependencies first
sudo systemctl start <dependency>
sudo systemctl start <service>
```

#### 5. Permission Issues
```bash
# Check service user
ps aux | grep <service>

# Check file permissions
sudo ls -la /var/log/<service>/
sudo ls -la /etc/<service>/
sudo ls -la /var/lib/<service>/

# Fix permissions if needed
sudo chown -R <user>:<group> /path/to/directory
sudo chmod 750 /path/to/directory
```

#### 6. Database Connection Issues
```bash
# Test database connection
mysql -u <user> -p -h <host>
psql -U <user> -h <host> -d <database>

# Check database service
sudo systemctl status mysql
sudo systemctl status postgresql

# Check database logs
sudo tail /var/log/mysql/error.log
sudo tail /var/log/postgresql/postgresql-*-main.log
```

## Service-Specific Recovery

### Nginx/Apache Down
```bash
# Check configuration
sudo nginx -t

# Check error logs
sudo tail -n 50 /var/log/nginx/error.log

# Restart
sudo systemctl restart nginx

# If still failing, check upstream services
sudo systemctl status php-fpm
curl http://localhost:3000  # Check backend
```

### Docker Container Down
```bash
# Check container status
docker ps -a | grep <container>

# Check why it stopped
docker inspect <container> | grep -A 10 State

# Check logs
docker logs <container> --tail 100

# Restart
docker restart <container>

# If restart policy is missing
docker update --restart=unless-stopped <container>

# Or use docker-compose
docker-compose up -d <service>
```

### Database Down
```bash
# PostgreSQL
sudo systemctl status postgresql
sudo -u postgres psql  # Test connection
sudo tail /var/log/postgresql/postgresql-*-main.log

# MySQL
sudo systemctl status mysql
sudo mysql  # Test connection
sudo tail /var/log/mysql/error.log

# Common fixes
sudo systemctl restart postgresql
sudo systemctl restart mysql
```

### Application Service Down
```bash
# Check application logs
sudo journalctl -u <app-service> -n 100

# Common issues:
# - Environment variables missing
# - Dependencies not installed
# - Config file errors
# - Port conflicts

# Verify environment
sudo systemctl show <service> | grep Environment

# Manual start for debugging
sudo -u <service-user> /path/to/application --debug
```

## Prevention

### 1. Enable Auto-Restart
```bash
# Edit service file
sudo systemctl edit <service>

# Add restart policy
[Service]
Restart=always
RestartSec=10s
StartLimitInterval=200
StartLimitBurst=5
```

### 2. Set Up Health Checks
```bash
# Add health check monitoring
./scripts/monitoring/health-check.py --config inventory/servers.yaml

# Configure alerts
./scripts/alerting/notify.sh --test
```

### 3. Implement Monitoring
```bash
# Set up Prometheus + Grafana
./scripts/monitoring/setup-prometheus-grafana.sh install

# Monitor specific service
sudo systemctl status <service> --no-pager
```

### 4. Create Systemd Service Properly
```bash
# Use service generator
./scripts/services/create-service.sh <service-name>

# Or create manually with proper settings
sudo nano /etc/systemd/system/<service>.service
```

Example service file:
```ini
[Unit]
Description=My Application
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

# Resource limits
LimitNOFILE=65536
MemoryLimit=2G

[Install]
WantedBy=multi-user.target
```

### 5. Implement Graceful Degradation
- Use circuit breakers
- Implement retry logic with backoff
- Add fallback mechanisms
- Use load balancers with health checks

## Verification

After service is restored:
```bash
# Verify service is running
sudo systemctl status <service>

# Check it's listening
sudo netstat -tlnp | grep <port>

# Test functionality
curl -I http://localhost:<port>

# Check logs for errors
sudo journalctl -u <service> -n 50 --no-pager

# Monitor for stability (5 minutes)
watch -n 5 'sudo systemctl status <service> | head -20'
```

## Post-Incident

1. **Document root cause** in incident log
2. **Review logs** for error patterns
3. **Update runbook** with lessons learned
4. **Implement prevention** measures
5. **Set up alerts** if not present
6. **Review capacity** and scaling needs
7. **Test recovery** procedures

## Escalation

If service cannot be restored:
1. Check backup and disaster recovery procedures
2. Consider failover to backup server
3. Notify stakeholders
4. Implement workaround if possible
5. Contact vendor support if commercial software

## Related Scripts

- `scripts/services/create-service.sh` - Create systemd services
- `scripts/monitoring/health-check.py` - Service monitoring
- `scripts/alerting/notify.sh` - Alert on downtime

## Additional Resources

- [systemd service management](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Docker restart policies](https://docs.docker.com/config/containers/start-containers-automatically/)
- [Nginx troubleshooting](https://nginx.org/en/docs/debugging_log.html)

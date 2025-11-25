# Runbook: High CPU Usage

## Overview
Steps to diagnose and resolve high CPU usage on Linux servers.

## Severity
**Medium to High** - Can cause performance degradation

## Symptoms
- Slow application response times
- System lag and unresponsiveness
- Load average > number of CPU cores
- Fan noise (physical servers)

## Immediate Diagnosis

### 1. Check Current CPU Usage
```bash
# Quick view
top

# Interactive with better UI
htop

# One-time snapshot
mpstat 1 5
```

### 2. Identify Top Processes
```bash
# Top CPU consumers
ps aux --sort=-%cpu | head -10

# By process tree
ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -20
```

### 3. Check System Load
```bash
# Load average (1min, 5min, 15min)
uptime

# Number of CPU cores (compare with load average)
nproc
```

**Healthy load:** < number of CPU cores
**Warning:** 1.5-2x number of cores
**Critical:** > 2x number of cores

## Common Causes & Solutions

### Runaway Process

**Symptoms:** Single process consuming >90% CPU

```bash
# Identify the process
top -o %CPU

# Check what it's doing
ps aux | grep <process-name>
strace -p <PID>

# If safe to kill
sudo kill -15 <PID>  # Graceful
sudo kill -9 <PID>   # Force (last resort)

# If it's a service
sudo systemctl restart <service-name>
```

### Database Query Issues

**Symptoms:** MySQL/PostgreSQL using excessive CPU

```bash
# MySQL - check running queries
mysql -u root -p -e "SHOW PROCESSLIST;"

# Kill slow query
mysql -u root -p -e "KILL <query_id>;"

# PostgreSQL - check running queries
sudo -u postgres psql -c "SELECT pid, query, state FROM pg_stat_activity WHERE state = 'active';"

# Terminate slow query
sudo -u postgres psql -c "SELECT pg_terminate_backend(<pid>);"
```

### Docker Container Issues

**Symptoms:** Container using excessive CPU

```bash
# Check container stats
docker stats --no-stream

# Inspect specific container
docker inspect <container-id>

# Check container logs
docker logs <container-id> --tail 100

# Restart container
docker restart <container-id>

# Limit CPU usage
docker update --cpus="2.0" <container-id>
```

### Too Many Processes/Threads

**Symptoms:** Many processes competing for CPU

```bash
# Count processes
ps aux | wc -l

# Find process creating many children
ps -eLf | awk '{print $4}' | sort | uniq -c | sort -rn | head

# Check for fork bombs or runaway scripts
ps -eLf | grep -E "bash|python|php"
```

### I/O Wait Causing High CPU

**Symptoms:** High %wa in top/htop

```bash
# Check I/O wait
iostat -x 1 5

# Find processes doing heavy I/O
iotop -o

# Check disk usage
df -h
```

See [disk-full.md](disk-full.md) runbook if disk is full.

### Crypto Mining Malware

**Symptoms:** Unknown processes with high CPU, names like xmrig, minerd

```bash
# Look for suspicious processes
ps aux | grep -E "miner|xmr|crypto|cpuminer"

# Check cron jobs
crontab -l
sudo crontab -l
ls /etc/cron.d/

# Kill and remove
sudo kill -9 <PID>
sudo find / -name "*miner*" -delete

# Scan for rootkits
sudo rkhunter --check
sudo chkrootkit
```

## Advanced Diagnostics

### Profile CPU Usage Over Time
```bash
# Install perf tools
sudo apt install linux-tools-common linux-tools-generic

# Record CPU usage
sudo perf record -a -g sleep 30

# Analyze results
sudo perf report
```

### Check for CPU Throttling
```bash
# Current CPU frequency
cat /proc/cpuinfo | grep MHz

# Thermal throttling
sensors  # Install: apt install lm-sensors
```

### Check for CPU-Bound Containers
```bash
# Docker container CPU limits
docker inspect <container> | grep -i cpu

# Set CPU limits
docker update --cpus="1.5" --cpu-shares=512 <container>
```

## Prevention

### 1. Set Resource Limits

**System-wide limits:**
```bash
# Edit limits
sudo nano /etc/security/limits.conf

# Example: limit max processes per user
* soft nproc 4096
* hard nproc 8192
```

**Docker container limits:**
```bash
# In docker-compose.yml
services:
  app:
    cpus: 2.0
    cpu_shares: 512
    mem_limit: 1g
```

### 2. Monitor with Alerts
```bash
# Set up health monitoring with CPU alerts
./scripts/monitoring/health-check.py --config inventory/servers.yaml

# Configure notification
./scripts/alerting/notify.sh -c all -l warning "High CPU detected"
```

### 3. Use Process Managers

**For Node.js apps:**
```bash
pm2 start app.js --max-memory-restart 500M
pm2 startup
```

**For Python apps:**
```bash
# Use systemd with resource limits
sudo nano /etc/systemd/system/myapp.service

# Add resource limits
[Service]
CPUQuota=200%
MemoryLimit=1G
TasksMax=512
```

### 4. Schedule Resource-Intensive Tasks
```bash
# Run backups and maintenance during off-peak hours
crontab -e

# Example: run at 2 AM
0 2 * * * /path/to/backup-script.sh
```

## Performance Tuning

### Optimize Application
- Review and optimize database queries
- Add caching (Redis, Memcached)
- Enable compression
- Use connection pooling
- Implement rate limiting

### System Tuning
```bash
# Adjust kernel parameters
sudo nano /etc/sysctl.conf

# Increase file descriptors
fs.file-max = 65536

# Network optimization
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048

# Apply changes
sudo sysctl -p
```

## Verification

After mitigation:
```bash
# Check CPU usage is back to normal
top
htop

# Verify load average
uptime

# Check application response times
curl -o /dev/null -s -w "Time: %{time_total}s\n" https://yoursite.com
```

## Post-Incident

1. Document the root cause
2. Review application logs for errors
3. Implement monitoring if not present
4. Consider scaling (vertical or horizontal)
5. Review capacity planning

## Related Scripts

- `scripts/monitoring/health-check.py` - Monitor CPU usage
- `scripts/performance/tune-kernel.sh` - System optimization
- `scripts/alerting/notify.sh` - CPU alerts

## Additional Resources

- [Linux Performance Tools](http://www.brendangregg.com/linuxperf.html)
- [htop explained](https://peteris.rocks/blog/htop/)
- [Understanding load average](https://www.brendangregg.com/blog/2017-08-08/linux-load-averages.html)

#!/usr/bin/env python3

"""
health-check.py

Multi-server health monitoring system
Collects metrics from servers and stores results for web UI display

Features:
- SSH into servers and collect metrics
- Monitor: CPU, memory, disk, uptime, services, Docker containers
- Store results in JSON for web dashboard
- Alert on critical thresholds
- Historical data tracking

Usage:
    ./health-check.py [options]

Options:
    --config FILE       Configuration file (default: config/servers.yaml)
    --output DIR        Output directory for results (default: /var/www/health-monitor)
    --once              Run once and exit (default: continuous)
    --interval N        Check interval in seconds (default: 60)
    --verbose           Verbose output
"""

import subprocess
import json
import yaml
import time
import sys
import os
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional

# Configuration
DEFAULT_CONFIG = "inventory/servers.yaml"
DEFAULT_OUTPUT = "/tmp/health-monitor"
DEFAULT_INTERVAL = 60

class Colors:
    """ANSI color codes"""
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'

class HealthChecker:
    """Health check monitoring system"""

    def __init__(self, config_file: str, output_dir: str, verbose: bool = False):
        self.config_file = config_file
        self.output_dir = Path(output_dir)
        self.verbose = verbose
        self.servers = []
        self.results = {}

        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        (self.output_dir / "history").mkdir(exist_ok=True)

        # Load configuration
        self.load_config()

    def log(self, message: str, level: str = "info"):
        """Log a message with color"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        colors = {
            "info": Colors.BLUE,
            "success": Colors.GREEN,
            "warning": Colors.YELLOW,
            "error": Colors.RED,
            "stat": Colors.CYAN,
        }

        color = colors.get(level, Colors.NC)
        print(f"{color}[{timestamp}] {message}{Colors.NC}")

    def load_config(self):
        """Load server configuration from YAML"""
        try:
            with open(self.config_file, 'r') as f:
                config = yaml.safe_load(f)

            # Flatten server list from all groups
            if 'servers' in config:
                for group, server_list in config['servers'].items():
                    if isinstance(server_list, list):
                        self.servers.extend(server_list)

            self.log(f"Loaded {len(self.servers)} server(s) from config", "success")

        except FileNotFoundError:
            self.log(f"Config file not found: {self.config_file}", "error")
            sys.exit(1)
        except Exception as e:
            self.log(f"Error loading config: {e}", "error")
            sys.exit(1)

    def ssh_execute(self, server: Dict[str, str], command: str, timeout: int = 10) -> Optional[str]:
        """Execute command on remote server via SSH"""
        ssh_user = server.get('ssh_user', 'root')
        ssh_port = server.get('ssh_port', 22)
        ip = server.get('ip')

        if not ip:
            return None

        ssh_cmd = [
            'ssh',
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'ConnectTimeout=5',
            '-o', 'BatchMode=yes',
            '-p', str(ssh_port),
            f'{ssh_user}@{ip}',
            command
        ]

        try:
            result = subprocess.run(
                ssh_cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )

            if result.returncode == 0:
                return result.stdout.strip()
            else:
                if self.verbose:
                    self.log(f"SSH command failed on {server['name']}: {result.stderr}", "warning")
                return None

        except subprocess.TimeoutExpired:
            if self.verbose:
                self.log(f"SSH timeout on {server['name']}", "warning")
            return None
        except Exception as e:
            if self.verbose:
                self.log(f"SSH error on {server['name']}: {e}", "error")
            return None

    def check_server_reachable(self, server: Dict[str, str]) -> bool:
        """Check if server is reachable via ping"""
        ip = server.get('ip')
        try:
            result = subprocess.run(
                ['ping', '-c', '1', '-W', '2', ip],
                capture_output=True,
                timeout=3
            )
            return result.returncode == 0
        except:
            return False

    def get_uptime(self, server: Dict[str, str]) -> Optional[str]:
        """Get server uptime"""
        output = self.ssh_execute(server, "uptime -p")
        return output if output else "Unknown"

    def get_cpu_usage(self, server: Dict[str, str]) -> Optional[float]:
        """Get CPU usage percentage"""
        output = self.ssh_execute(
            server,
            "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1"
        )
        try:
            return float(output) if output else None
        except:
            return None

    def get_memory_usage(self, server: Dict[str, str]) -> Optional[Dict[str, Any]]:
        """Get memory usage"""
        output = self.ssh_execute(server, "free -m | grep Mem")
        if not output:
            return None

        try:
            parts = output.split()
            total = int(parts[1])
            used = int(parts[2])
            free = int(parts[3])
            percent = round((used / total) * 100, 1)

            return {
                'total': total,
                'used': used,
                'free': free,
                'percent': percent
            }
        except:
            return None

    def get_disk_usage(self, server: Dict[str, str]) -> Optional[List[Dict[str, Any]]]:
        """Get disk usage for all mounted filesystems"""
        output = self.ssh_execute(
            server,
            "df -h | grep -E '^/dev/' | awk '{print $1,$2,$3,$4,$5,$6}'"
        )
        if not output:
            return None

        disks = []
        for line in output.split('\n'):
            parts = line.split()
            if len(parts) >= 6:
                try:
                    disks.append({
                        'device': parts[0],
                        'size': parts[1],
                        'used': parts[2],
                        'available': parts[3],
                        'percent': int(parts[4].rstrip('%')),
                        'mount': parts[5]
                    })
                except:
                    continue

        return disks if disks else None

    def get_load_average(self, server: Dict[str, str]) -> Optional[Dict[str, float]]:
        """Get system load average"""
        output = self.ssh_execute(server, "cat /proc/loadavg")
        if not output:
            return None

        try:
            parts = output.split()
            return {
                '1min': float(parts[0]),
                '5min': float(parts[1]),
                '15min': float(parts[2])
            }
        except:
            return None

    def get_docker_containers(self, server: Dict[str, str]) -> Optional[Dict[str, Any]]:
        """Get Docker container status"""
        output = self.ssh_execute(
            server,
            "docker ps -a --format '{{.Names}}|{{.Status}}|{{.State}}' 2>/dev/null || echo 'NOT_INSTALLED'"
        )

        if not output or output == "NOT_INSTALLED":
            return None

        containers = []
        running = 0
        stopped = 0

        for line in output.split('\n'):
            if '|' not in line:
                continue

            parts = line.split('|')
            if len(parts) >= 3:
                name, status, state = parts[0], parts[1], parts[2]
                containers.append({
                    'name': name,
                    'status': status,
                    'state': state
                })

                if state == 'running':
                    running += 1
                else:
                    stopped += 1

        return {
            'total': len(containers),
            'running': running,
            'stopped': stopped,
            'containers': containers
        }

    def get_services_status(self, server: Dict[str, str], services: List[str] = None) -> Optional[List[Dict[str, Any]]]:
        """Check status of systemd services"""
        if not services:
            services = ['ssh', 'docker', 'nginx', 'postgresql', 'mysql']

        results = []
        for service in services:
            output = self.ssh_execute(
                server,
                f"systemctl is-active {service} 2>/dev/null || echo 'not-found'"
            )

            if output and output != "not-found":
                results.append({
                    'name': service,
                    'status': output,
                    'running': output == 'active'
                })

        return results if results else None

    def check_server(self, server: Dict[str, str]) -> Dict[str, Any]:
        """Perform comprehensive health check on a server"""
        server_name = server.get('name', 'Unknown')
        self.log(f"Checking {server_name}...", "info")

        result = {
            'name': server_name,
            'ip': server.get('ip'),
            'type': server.get('type', 'unknown'),
            'timestamp': datetime.now().isoformat(),
            'reachable': False,
            'status': 'down',
            'metrics': {}
        }

        # Check if server is reachable
        if not self.check_server_reachable(server):
            self.log(f"  {server_name}: UNREACHABLE", "error")
            return result

        result['reachable'] = True

        # Collect metrics
        result['metrics']['uptime'] = self.get_uptime(server)
        result['metrics']['cpu'] = self.get_cpu_usage(server)
        result['metrics']['memory'] = self.get_memory_usage(server)
        result['metrics']['disk'] = self.get_disk_usage(server)
        result['metrics']['load'] = self.get_load_average(server)
        result['metrics']['docker'] = self.get_docker_containers(server)
        result['metrics']['services'] = self.get_services_status(server)

        # Determine overall status
        status = "healthy"
        warnings = []

        # Check CPU
        if result['metrics']['cpu'] and result['metrics']['cpu'] > 80:
            status = "warning"
            warnings.append(f"High CPU: {result['metrics']['cpu']}%")

        # Check memory
        if result['metrics']['memory'] and result['metrics']['memory']['percent'] > 85:
            status = "warning"
            warnings.append(f"High Memory: {result['metrics']['memory']['percent']}%")

        # Check disk
        if result['metrics']['disk']:
            for disk in result['metrics']['disk']:
                if disk['percent'] > 85:
                    status = "critical" if disk['percent'] > 95 else "warning"
                    warnings.append(f"High Disk ({disk['mount']}): {disk['percent']}%")

        result['status'] = status
        result['warnings'] = warnings

        if status == "healthy":
            self.log(f"  {server_name}: OK", "success")
        elif status == "warning":
            self.log(f"  {server_name}: WARNING - {', '.join(warnings)}", "warning")
        else:
            self.log(f"  {server_name}: CRITICAL - {', '.join(warnings)}", "error")

        return result

    def run_checks(self):
        """Run health checks on all servers"""
        self.log("=" * 60, "info")
        self.log(f"Starting health checks for {len(self.servers)} server(s)", "info")
        self.log("=" * 60, "info")

        results = []

        for server in self.servers:
            try:
                result = self.check_server(server)
                results.append(result)
            except Exception as e:
                self.log(f"Error checking {server.get('name')}: {e}", "error")

        # Save results
        self.save_results(results)

        # Summary
        healthy = sum(1 for r in results if r['status'] == 'healthy')
        warning = sum(1 for r in results if r['status'] == 'warning')
        critical = sum(1 for r in results if r['status'] == 'critical')
        down = sum(1 for r in results if not r['reachable'])

        self.log("=" * 60, "info")
        self.log(f"Check completed: {healthy} healthy, {warning} warning, {critical} critical, {down} down", "stat")
        self.log("=" * 60, "info")

        return results

    def save_results(self, results: List[Dict[str, Any]]):
        """Save check results to JSON files"""
        # Save current results
        current_file = self.output_dir / "current.json"
        with open(current_file, 'w') as f:
            json.dump({
                'timestamp': datetime.now().isoformat(),
                'servers': results
            }, f, indent=2)

        # Save to history
        history_file = self.output_dir / "history" / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(history_file, 'w') as f:
            json.dump({
                'timestamp': datetime.now().isoformat(),
                'servers': results
            }, f, indent=2)

        # Clean old history (keep last 1000 files)
        history_files = sorted((self.output_dir / "history").glob("*.json"))
        if len(history_files) > 1000:
            for old_file in history_files[:-1000]:
                old_file.unlink()

        self.log(f"Results saved to {current_file}", "success")

    def run_continuous(self, interval: int):
        """Run health checks continuously"""
        self.log(f"Starting continuous monitoring (interval: {interval}s)", "info")
        self.log("Press Ctrl+C to stop", "info")

        try:
            while True:
                self.run_checks()
                time.sleep(interval)
        except KeyboardInterrupt:
            self.log("\nStopped by user", "info")

def main():
    parser = argparse.ArgumentParser(description="Multi-server health monitoring")
    parser.add_argument('--config', default=DEFAULT_CONFIG, help='Configuration file')
    parser.add_argument('--output', default=DEFAULT_OUTPUT, help='Output directory')
    parser.add_argument('--once', action='store_true', help='Run once and exit')
    parser.add_argument('--interval', type=int, default=DEFAULT_INTERVAL, help='Check interval (seconds)')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')

    args = parser.parse_args()

    # Initialize checker
    checker = HealthChecker(args.config, args.output, args.verbose)

    # Run checks
    if args.once:
        checker.run_checks()
    else:
        checker.run_continuous(args.interval)

if __name__ == "__main__":
    main()

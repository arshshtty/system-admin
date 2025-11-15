#!/usr/bin/env python3

"""
web-dashboard.py

Web UI for health monitoring dashboard
Displays real-time server health status with auto-refresh

Features:
- Real-time server status display
- Auto-refresh every 30 seconds
- Status indicators (healthy, warning, critical, down)
- Detailed metrics for each server
- Historical data view
- Responsive design

Usage:
    ./web-dashboard.py [options]

Options:
    --data-dir DIR      Data directory with health check results
    --port PORT         Web server port (default: 8080)
    --host HOST         Web server host (default: 0.0.0.0)
    --debug             Enable debug mode
"""

import json
import argparse
from pathlib import Path
from datetime import datetime
from flask import Flask, render_template_string, jsonify, send_from_directory
import os

DEFAULT_DATA_DIR = "/tmp/health-monitor"
DEFAULT_PORT = 8080
DEFAULT_HOST = "0.0.0.0"

app = Flask(__name__)
data_dir = Path(DEFAULT_DATA_DIR)

# HTML Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Health Monitor</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        .header {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
        }

        .header h1 {
            font-size: 2.5em;
            color: #2d3748;
            margin-bottom: 10px;
        }

        .header .meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 15px;
            color: #718096;
        }

        .refresh-info {
            font-size: 0.9em;
        }

        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .summary-card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
        }

        .summary-card .number {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }

        .summary-card .label {
            color: #718096;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .summary-card.healthy .number { color: #48bb78; }
        .summary-card.warning .number { color: #ed8936; }
        .summary-card.critical .number { color: #f56565; }
        .summary-card.down .number { color: #a0aec0; }

        .servers-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
            gap: 20px;
        }

        .server-card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }

        .server-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 50px rgba(0, 0, 0, 0.15);
        }

        .server-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #e2e8f0;
        }

        .server-name {
            font-size: 1.4em;
            font-weight: bold;
            color: #2d3748;
        }

        .status-badge {
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .status-badge.healthy {
            background: #c6f6d5;
            color: #22543d;
        }

        .status-badge.warning {
            background: #feebc8;
            color: #7c2d12;
        }

        .status-badge.critical {
            background: #fed7d7;
            color: #742a2a;
        }

        .status-badge.down {
            background: #e2e8f0;
            color: #2d3748;
        }

        .server-info {
            margin-bottom: 15px;
            color: #4a5568;
            font-size: 0.9em;
        }

        .server-info span {
            display: inline-block;
            margin-right: 15px;
        }

        .metric {
            margin-bottom: 15px;
        }

        .metric-label {
            font-size: 0.85em;
            color: #718096;
            margin-bottom: 5px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .metric-value {
            font-size: 1.1em;
            color: #2d3748;
            font-weight: 500;
        }

        .progress-bar {
            background: #e2e8f0;
            border-radius: 10px;
            height: 10px;
            overflow: hidden;
            margin-top: 5px;
        }

        .progress-fill {
            height: 100%;
            border-radius: 10px;
            transition: width 0.3s;
        }

        .progress-fill.low { background: #48bb78; }
        .progress-fill.medium { background: #ed8936; }
        .progress-fill.high { background: #f56565; }

        .warnings {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 12px;
            margin-top: 15px;
            border-radius: 4px;
        }

        .warnings ul {
            margin-left: 20px;
            color: #856404;
        }

        .docker-info {
            display: flex;
            gap: 15px;
            margin-top: 10px;
        }

        .docker-stat {
            flex: 1;
            text-align: center;
            padding: 10px;
            background: #f7fafc;
            border-radius: 6px;
        }

        .docker-stat .num {
            font-size: 1.5em;
            font-weight: bold;
            color: #2d3748;
        }

        .docker-stat .label {
            font-size: 0.8em;
            color: #718096;
        }

        .loading {
            text-align: center;
            padding: 50px;
            color: white;
            font-size: 1.2em;
        }

        @media (max-width: 768px) {
            .servers-grid {
                grid-template-columns: 1fr;
            }

            .header h1 {
                font-size: 1.8em;
            }
        }

        .auto-refresh {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: rgba(255, 255, 255, 0.95);
            padding: 10px 20px;
            border-radius: 20px;
            box-shadow: 0 5px 20px rgba(0, 0, 0, 0.15);
            font-size: 0.9em;
            color: #718096;
        }

        .pulse {
            display: inline-block;
            width: 8px;
            height: 8px;
            background: #48bb78;
            border-radius: 50%;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ Server Health Monitor</h1>
            <div class="meta">
                <div class="refresh-info">
                    Last updated: <strong id="last-update">Loading...</strong>
                </div>
                <div class="refresh-info">
                    Total Servers: <strong id="total-servers">-</strong>
                </div>
            </div>
        </div>

        <div class="summary" id="summary">
            <!-- Summary cards will be inserted here -->
        </div>

        <div class="servers-grid" id="servers">
            <div class="loading">Loading server data...</div>
        </div>
    </div>

    <div class="auto-refresh">
        <span class="pulse"></span>
        Auto-refresh every 30s
    </div>

    <script>
        function formatUptime(uptime) {
            return uptime || 'Unknown';
        }

        function formatBytes(mb) {
            return mb >= 1024 ? `${(mb / 1024).toFixed(1)} GB` : `${mb} MB`;
        }

        function getProgressClass(percent) {
            if (percent < 70) return 'low';
            if (percent < 85) return 'medium';
            return 'high';
        }

        function renderSummary(data) {
            const servers = data.servers || [];
            const healthy = servers.filter(s => s.status === 'healthy').length;
            const warning = servers.filter(s => s.status === 'warning').length;
            const critical = servers.filter(s => s.status === 'critical').length;
            const down = servers.filter(s => !s.reachable).length;

            document.getElementById('total-servers').textContent = servers.length;

            const summaryHTML = `
                <div class="summary-card healthy">
                    <div class="number">${healthy}</div>
                    <div class="label">Healthy</div>
                </div>
                <div class="summary-card warning">
                    <div class="number">${warning}</div>
                    <div class="label">Warning</div>
                </div>
                <div class="summary-card critical">
                    <div class="number">${critical}</div>
                    <div class="label">Critical</div>
                </div>
                <div class="summary-card down">
                    <div class="number">${down}</div>
                    <div class="label">Down</div>
                </div>
            `;

            document.getElementById('summary').innerHTML = summaryHTML;
        }

        function renderServers(data) {
            const servers = data.servers || [];
            const timestamp = new Date(data.timestamp).toLocaleString();

            document.getElementById('last-update').textContent = timestamp;

            if (servers.length === 0) {
                document.getElementById('servers').innerHTML = '<div class="loading">No server data available</div>';
                return;
            }

            const serversHTML = servers.map(server => {
                const metrics = server.metrics || {};
                const status = server.reachable ? server.status : 'down';

                let content = `
                    <div class="server-card">
                        <div class="server-header">
                            <div class="server-name">${server.name}</div>
                            <div class="status-badge ${status}">${status}</div>
                        </div>
                        <div class="server-info">
                            <span>📍 ${server.ip}</span>
                            <span>🏷️ ${server.type}</span>
                        </div>
                `;

                if (!server.reachable) {
                    content += '<div class="warnings"><strong>⚠️ Server Unreachable</strong></div>';
                } else {
                    // Uptime
                    if (metrics.uptime) {
                        content += `
                            <div class="metric">
                                <div class="metric-label">Uptime</div>
                                <div class="metric-value">⏱️ ${formatUptime(metrics.uptime)}</div>
                            </div>
                        `;
                    }

                    // CPU
                    if (metrics.cpu !== null && metrics.cpu !== undefined) {
                        const cpuClass = getProgressClass(metrics.cpu);
                        content += `
                            <div class="metric">
                                <div class="metric-label">CPU Usage</div>
                                <div class="metric-value">${metrics.cpu.toFixed(1)}%</div>
                                <div class="progress-bar">
                                    <div class="progress-fill ${cpuClass}" style="width: ${metrics.cpu}%"></div>
                                </div>
                            </div>
                        `;
                    }

                    // Memory
                    if (metrics.memory) {
                        const mem = metrics.memory;
                        const memClass = getProgressClass(mem.percent);
                        content += `
                            <div class="metric">
                                <div class="metric-label">Memory Usage</div>
                                <div class="metric-value">${mem.percent}% (${formatBytes(mem.used)} / ${formatBytes(mem.total)})</div>
                                <div class="progress-bar">
                                    <div class="progress-fill ${memClass}" style="width: ${mem.percent}%"></div>
                                </div>
                            </div>
                        `;
                    }

                    // Disk
                    if (metrics.disk && metrics.disk.length > 0) {
                        metrics.disk.forEach(disk => {
                            const diskClass = getProgressClass(disk.percent);
                            content += `
                                <div class="metric">
                                    <div class="metric-label">Disk ${disk.mount}</div>
                                    <div class="metric-value">${disk.percent}% (${disk.used} / ${disk.size})</div>
                                    <div class="progress-bar">
                                        <div class="progress-fill ${diskClass}" style="width: ${disk.percent}%"></div>
                                    </div>
                                </div>
                            `;
                        });
                    }

                    // Docker
                    if (metrics.docker) {
                        const docker = metrics.docker;
                        content += `
                            <div class="metric">
                                <div class="metric-label">Docker Containers</div>
                                <div class="docker-info">
                                    <div class="docker-stat">
                                        <div class="num">${docker.total}</div>
                                        <div class="label">Total</div>
                                    </div>
                                    <div class="docker-stat">
                                        <div class="num">${docker.running}</div>
                                        <div class="label">Running</div>
                                    </div>
                                    <div class="docker-stat">
                                        <div class="num">${docker.stopped}</div>
                                        <div class="label">Stopped</div>
                                    </div>
                                </div>
                            </div>
                        `;
                    }

                    // Warnings
                    if (server.warnings && server.warnings.length > 0) {
                        content += `
                            <div class="warnings">
                                <strong>⚠️ Warnings:</strong>
                                <ul>
                                    ${server.warnings.map(w => `<li>${w}</li>`).join('')}
                                </ul>
                            </div>
                        `;
                    }
                }

                content += '</div>';
                return content;
            }).join('');

            document.getElementById('servers').innerHTML = serversHTML;
        }

        async function loadData() {
            try {
                const response = await fetch('/api/current');
                const data = await response.json();
                renderSummary(data);
                renderServers(data);
            } catch (error) {
                console.error('Error loading data:', error);
                document.getElementById('servers').innerHTML = '<div class="loading">Error loading server data</div>';
            }
        }

        // Initial load
        loadData();

        // Auto-refresh every 30 seconds
        setInterval(loadData, 30000);
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """Render main dashboard"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/current')
def api_current():
    """API endpoint for current health data"""
    current_file = data_dir / "current.json"

    if not current_file.exists():
        return jsonify({
            'timestamp': datetime.now().isoformat(),
            'servers': []
        })

    try:
        with open(current_file, 'r') as f:
            data = json.load(f)
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/history')
def api_history():
    """API endpoint for historical data"""
    history_dir = data_dir / "history"

    if not history_dir.exists():
        return jsonify([])

    try:
        files = sorted(history_dir.glob("*.json"), reverse=True)[:100]
        history = []

        for file in files:
            with open(file, 'r') as f:
                history.append(json.load(f))

        return jsonify(history)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def main():
    parser = argparse.ArgumentParser(description="Health monitoring web dashboard")
    parser.add_argument('--data-dir', default=DEFAULT_DATA_DIR, help='Data directory')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT, help='Web server port')
    parser.add_argument('--host', default=DEFAULT_HOST, help='Web server host')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')

    args = parser.parse_args()

    global data_dir
    data_dir = Path(args.data_dir)

    print(f"Starting health monitoring dashboard...")
    print(f"Data directory: {data_dir}")
    print(f"Dashboard URL: http://{args.host}:{args.port}")
    print(f"Press Ctrl+C to stop")

    app.run(host=args.host, port=args.port, debug=args.debug)

if __name__ == "__main__":
    main()

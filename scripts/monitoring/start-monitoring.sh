#!/usr/bin/env bash

#############################################################################
# start-monitoring.sh
#
# Quick start script for health monitoring system
# Starts both the health checker and web dashboard
#
# Usage:
#   ./start-monitoring.sh
#
#############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Starting Server Health Monitoring System${NC}"
echo ""

# Check Python dependencies
echo -e "${BLUE}Checking Python dependencies...${NC}"
if ! python3 -c "import flask, yaml" 2>/dev/null; then
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    pip3 install -r "${REPO_ROOT}/requirements.txt" --user
fi

# Check if servers.yaml exists
if [ ! -f "${REPO_ROOT}/inventory/servers.yaml" ]; then
    echo -e "${YELLOW}⚠️  Warning: inventory/servers.yaml not found!${NC}"
    echo "Please create it based on inventory/example.yaml"
    echo "Continuing with example config..."
    CONFIG_FILE="${REPO_ROOT}/inventory/example.yaml"
else
    CONFIG_FILE="${REPO_ROOT}/inventory/servers.yaml"
fi

# Start health checker in background
echo -e "${BLUE}Starting health checker...${NC}"
python3 "${SCRIPT_DIR}/health-check.py" \
    --config "$CONFIG_FILE" \
    --output /tmp/health-monitor \
    --interval 60 &

CHECKER_PID=$!
echo -e "${GREEN}✓ Health checker started (PID: $CHECKER_PID)${NC}"

# Wait for initial data
sleep 3

# Start web dashboard
echo -e "${BLUE}Starting web dashboard...${NC}"
python3 "${SCRIPT_DIR}/web-dashboard.py" \
    --data-dir /tmp/health-monitor \
    --port 8080 \
    --host 0.0.0.0 &

DASHBOARD_PID=$!
echo -e "${GREEN}✓ Web dashboard started (PID: $DASHBOARD_PID)${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Health Monitoring System Started!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Dashboard URL: ${BLUE}http://localhost:8080${NC}"
echo -e "Data directory: ${BLUE}/tmp/health-monitor${NC}"
echo ""
echo -e "Health Checker PID: $CHECKER_PID"
echo -e "Dashboard PID: $DASHBOARD_PID"
echo ""
echo -e "To stop:"
echo -e "  kill $CHECKER_PID $DASHBOARD_PID"
echo ""
echo -e "Press Ctrl+C to stop both services"

# Wait for both processes
wait

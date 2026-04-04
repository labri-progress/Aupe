#!/bin/bash

# Script to fetch results_byz folder from remote nodes listed in /etc/ansible/hosts
# Usage: ./fetch_results_byz.sh [timestamp]
# If no timestamp provided, fetches the latest files

# Configuration
HOSTS_FILE="/etc/ansible/hosts"
REMOTE_DIR="~/Aupe/max_byz" # "~/Aupe/results_byz"
LOCAL_DIR="./fetched_results_byz"
TIMESTAMP=${1:-"latest"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create local directory with timestamp
if [ "$TIMESTAMP" == "latest" ]; then
    FETCH_DIR="${LOCAL_DIR}/$(date +%Y%m%d_%H%M%S)"
else
    FETCH_DIR="${LOCAL_DIR}/${TIMESTAMP}"
fi

mkdir -p "$FETCH_DIR"

echo -e "${GREEN}=== Fetching results_byz from Remote Nodes ===${NC}"
echo -e "Timestamp: ${YELLOW}${TIMESTAMP}${NC}"
echo -e "Target directory: ${YELLOW}${FETCH_DIR}${NC}"
echo ""

# Read nodes from ansible hosts file
if [ ! -f "$HOSTS_FILE" ]; then
    echo -e "${RED}Error: Hosts file not found: $HOSTS_FILE${NC}"
    exit 1
fi

# Get list of nodes (skip empty lines)
mapfile -t NODES < <(grep -v '^$' "$HOSTS_FILE")

if [ ${#NODES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No nodes found in $HOSTS_FILE${NC}"
    exit 1
fi

echo -e "Found ${GREEN}${#NODES[@]}${NC} nodes to process"
echo ""

# Counter for statistics
total_files=0
success_files=0
failed_files=0

# Fetch files from each node
for node in "${NODES[@]}"; do
    echo -e "${GREEN}Processing node: ${node}${NC}"

    # Create node-specific directory
    node_dir="${FETCH_DIR}/${node}"
    mkdir -p "$node_dir"

    # Fetch all files from results_byz directory
    echo -n "  Fetching results_byz/... "

    # Use scp to fetch the entire directory contents
    if scp -q -r "root@${node}:${REMOTE_DIR}/"* "$node_dir/" 2>/dev/null; then
        # Count fetched files
        count=$(ls -1 "$node_dir" 2>/dev/null | wc -l)
        size=$(du -sh "$node_dir" | cut -f1)
        echo -e "${GREEN}✓${NC} (${count} files, ${size})"
        success_files=$((success_files + count))
        total_files=$((total_files + count))
    else
        echo -e "${RED}✗ (directory not found or connection failed)${NC}"
        failed_files=$((failed_files + 1))
        total_files=$((total_files + 1))
    fi

    echo ""
done

# Summary
echo -e "${GREEN}=== Summary ===${NC}"
echo -e "Total files fetched:   ${GREEN}${success_files}${NC}"
echo -e "Failed nodes:          ${RED}${failed_files}${NC}"
echo -e "Results saved in:      ${YELLOW}${FETCH_DIR}${NC}"
echo ""

# Create a manifest file
manifest_file="${FETCH_DIR}/manifest.txt"
echo "Fetch Results Manifest" > "$manifest_file"
echo "======================" >> "$manifest_file"
echo "Date: $(date)" >> "$manifest_file"
echo "Timestamp: ${TIMESTAMP}" >> "$manifest_file"
echo "" >> "$manifest_file"
echo "Nodes processed:" >> "$manifest_file"
for node in "${NODES[@]}"; do
    echo "  - ${node}" >> "$manifest_file"
done
echo "" >> "$manifest_file"
echo "Statistics:" >> "$manifest_file"
echo "  Total files fetched: ${success_files}" >> "$manifest_file"
echo "  Failed nodes:        ${failed_files}" >> "$manifest_file"

echo -e "Manifest saved to: ${YELLOW}${manifest_file}${NC}"

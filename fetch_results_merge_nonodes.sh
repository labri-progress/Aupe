#!/bin/bash

# Script to fetch results_merge folder from remote nodes listed in /etc/ansible/hosts
# Excludes files whose names start with "nodes"
# Usage: ./fetch_results_merge_nonodes.sh [timestamp]
# If no timestamp provided, fetches the latest files

# Configuration
HOSTS_FILE="/etc/ansible/hosts"
REMOTE_DIR="~/Aupe/results_merge"
LOCAL_DIR="./fetched_results_merge"
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

echo -e "${GREEN}=== Fetching results_merge from Remote Nodes (excluding nodes* files) ===${NC}"
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

# Fetch one node in background; writes status to a tmp file
# Strategy: tar+gzip on the remote, pipe over SSH, extract locally
fetch_node() {
    local node="$1"
    local node_dir="$2"
    mkdir -p "$node_dir"
    if ssh -q "root@${node}" \
           "tar -czf - --exclude='nodes*' -C ${REMOTE_DIR} . 2>/dev/null" \
       | tar -xzf - -C "$node_dir" 2>/dev/null; then
        count=$(ls -1 "$node_dir" 2>/dev/null | wc -l)
        size=$(du -sh "$node_dir" | cut -f1)
        echo -e "${GREEN}✓${NC} ${node}: ${count} files, ${size}"
        echo "ok $count"
    else
        echo -e "${RED}✗${NC} ${node}: directory not found or connection failed"
        echo "fail 0"
    fi
}

# Launch all fetches in parallel
declare -A pids
declare -A tmp_files
for node in "${NODES[@]}"; do
    node_dir="${FETCH_DIR}/${node}"
    tmp=$(mktemp)
    tmp_files[$node]="$tmp"
    fetch_node "$node" "$node_dir" > "$tmp" &
    pids[$node]=$!
done

# Wait for all and collect results
success_files=0
failed_files=0
total_files=0
for node in "${NODES[@]}"; do
    wait "${pids[$node]}"
    tmp="${tmp_files[$node]}"
    # print the human-readable lines (all but last)
    head -n -1 "$tmp"
    # read the status line
    read -r status count < <(tail -n 1 "$tmp")
    rm -f "$tmp"
    if [ "$status" = "ok" ]; then
        success_files=$((success_files + count))
        total_files=$((total_files + count))
    else
        failed_files=$((failed_files + 1))
        total_files=$((total_files + 1))
    fi
done

echo ""
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

#!/bin/bash

set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 [--cluster-name <cluster-name>]"
    exit 1
}

# Parse arguments
ALIAS=
while [[ $# -gt 0 ]]; do
    case $1 in
        --alias)
            ALIAS="$2"
            shift
            shift
            ;;
        *)
            usage
            ;;
    esac
done

# Check if AWS CLI and 'kubectl' are installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install and configure it."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found. Please install it."
    exit 1
fi

# Use fzf for cluster selection
if ! command -v fzf &> /dev/null; then
    echo "fzf not found. Please install it."
    exit 1
fi

CLUSTER_NAME=$(aws eks list-clusters | jq -r '.clusters[]' | fzf --prompt "Select a cluster")
if [ -z "$CLUSTER_NAME" ]; then
    echo "No cluster selected"
    exit 1
fi

# Update the kubeconfig
echo "Adding cluster '$CLUSTER_NAME' to kubeconfig..."
if [ -z "$ALIAS" ]; then
    ALIAS="$CLUSTER_NAME"
fi
aws eks update-kubeconfig --name "$CLUSTER_NAME" --alias "$ALIAS"

echo "Cluster '$CLUSTER_NAME' added to kubeconfig successfully."

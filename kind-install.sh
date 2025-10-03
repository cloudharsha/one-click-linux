#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Installing kind (Kubernetes in Docker)..."

# Detect latest version
LATEST_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest \
  | grep '"tag_name":' | cut -d '"' -f 4)

if [[ -z "$LATEST_VERSION" ]]; then
  echo "❌ Failed to detect latest kind version"
  exit 1
fi

echo "Latest kind version: $LATEST_VERSION"

# Download binary
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${LATEST_VERSION}/kind-$(uname)-amd64"

# Move to /usr/local/bin
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

echo "✅ kind installed: $(kind --version)"

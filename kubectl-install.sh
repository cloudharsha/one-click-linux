#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Installing kubectl on Ubuntu/WSL..."

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' is required"; exit 1; }; }
need curl
need sudo

# Update + prereqs
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Kubernetes APT repo (idempotent)
if [[ ! -f /usr/share/keyrings/kubernetes-archive-keyring.gpg ]]; then
  curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
    https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /dev/null >/dev/null
fi

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kubectl

echo "✅ kubectl installed: $(kubectl version --client --short || true)"

# Optional sanity checks (non-fatal)
echo "🔎 Checking kube config/context (this may be empty if you don't have a cluster yet)..."
kubectl config get-contexts || true

echo "🎯 kubectl is ready."

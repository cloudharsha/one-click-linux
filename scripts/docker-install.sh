#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Installing Docker Engine + Compose v2 on Ubuntu/WSL..."

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' is required"; exit 1; }; }
need curl
need sudo

# Prereqs
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Docker repo (idempotent)
sudo install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
| sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Install
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (no-op if already there)
if id -nG "$USER" | grep -qw docker; then
  echo "ℹ️  User '$USER' already in docker group."
else
  echo "👥 Adding '$USER' to docker group..."
  sudo usermod -aG docker "$USER"
  echo "⚠️  Please log out/in, or on WSL run:  wsl --shutdown  (then reopen Ubuntu) to apply group changes."
fi

# Try to start service if systemd available (WSL may skip this)
if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl enable --now docker || true
fi

# Checks (non-fatal in WSL if daemon isn’t running yet)
echo "✅ Docker CLI: $(docker --version || echo 'docker not ready yet')"
echo "✅ Compose v2: $(docker compose version || echo 'compose not ready yet')"

echo "🎯 Docker setup complete."

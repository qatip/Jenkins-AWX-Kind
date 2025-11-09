#!/usr/bin/env bash
set -euo pipefail

# --- Make all apt operations non-interactive
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="-yq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

# Some packages prompt to restart services via 'needrestart'.
# This tells needrestart to auto-accept restarts.
echo 'NEEDRESTART_MODE=a' | sudo tee /etc/environment >/dev/null
sudo mkdir -p /etc/needrestart
sudo bash -c 'cat >/etc/needrestart/needrestart.conf' <<'EOF'
$nrconf{restart} = 'a';   # auto-restart services
EOF

# --- Base packages and Java 17
sudo apt-get update -y
sudo apt-get install $APT_FLAGS ca-certificates curl gnupg lsb-release

sudo apt-get install $APT_FLAGS openjdk-17-jdk

# --- Jenkins repo + install
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc >/dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null

sudo apt-get update -y
# NEEDRESTART_MODE=a ensures no pause for service restarts during install/upgrade
sudo NEEDRESTART_MODE=a apt-get install $APT_FLAGS jenkins

# --- Enable and start Jenkins
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins

# --- Show initial admin password
echo "Jenkins initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword || true

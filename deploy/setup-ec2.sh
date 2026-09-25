#!/usr/bin/env bash
# Run once on a fresh Ubuntu 24.04 EC2 instance.
set -euo pipefail
[[ $(id -u) == 0 ]] || { echo 'Run with sudo'; exit 1; }
export DEBIAN_FRONTEND=noninteractive
if ! swapon --show=NAME --noheadings | grep -q .; then
  if [[ ! -e /swapfile ]]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
fi
apt-get update
apt-get install -y ca-certificates curl git fontconfig openjdk-21-jre
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
echo 'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' > /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin jenkins
usermod -aG docker jenkins
usermod -aG docker ubuntu
systemctl enable --now docker jenkins
systemctl restart jenkins
echo 'Setup complete. Read password locally: sudo cat /var/lib/jenkins/secrets/initialAdminPassword'

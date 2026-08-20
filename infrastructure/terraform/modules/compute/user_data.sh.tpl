#!/bin/bash
# CloudMart backend bootstrap (Phase 4). Runs once, at first boot.
set -euxo pipefail

dnf update -y
dnf install -y git

# Node.js 20 via NodeSource (Amazon Linux 2023 ships no Node package by default)
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

cd /opt
git clone --branch ${repo_branch} --depth 1 ${repo_url} cloudmart-aws
cd cloudmart-aws/backend
npm install --omit=dev

cat >/etc/systemd/system/cloudmart-backend.service <<'UNIT'
[Unit]
Description=CloudMart backend API
After=network.target

[Service]
Environment=PORT=${app_port}
Environment=FRONTEND_ORIGIN=*
WorkingDirectory=/opt/cloudmart-aws/backend
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=5
User=ec2-user

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now cloudmart-backend

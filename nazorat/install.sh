#!/bin/bash
# Installs the Nazorat relay (live screen view for the supervised phone) on the VPN server.
# Usage (as root):  curl -fsSL https://raw.githubusercontent.com/JJJAAAXXX0206/vpn-update/main/nazorat/install.sh | bash -s NAME:CODE
# Does not touch 3x-ui / the VPN. Ports: 8443 (HTTPS), 8088 (HTTP fallback).
set -u
KEYS="${1:?usage: install.sh name:code}"
BASE=https://raw.githubusercontent.com/JJJAAAXXX0206/vpn-update/main/nazorat
exec > >(tee /root/nazorat-install.log) 2>&1

curl -fsSL "$BASE/nazorat-relay" -o /usr/local/bin/nazorat-relay.new && \
  chmod 755 /usr/local/bin/nazorat-relay.new && mv /usr/local/bin/nazorat-relay.new /usr/local/bin/nazorat-relay || { echo "DOWNLOAD FAILED"; exit 1; }

# Let's Encrypt IP certificate (same place 3x-ui keeps it); relay falls back to HTTP if this fails.
IP=$(curl -fsS4 https://api.ipify.org || hostname -I | awk '{print $1}')
if [ ! -s /root/cert/ip/fullchain.pem ]; then
  [ -x ~/.acme.sh/acme.sh ] || curl -fsSL https://get.acme.sh | sh
  command -v socat >/dev/null || apt-get install -y socat
  mkdir -p /root/cert/ip
  ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
  ~/.acme.sh/acme.sh --issue -d "$IP" --standalone --httpport 80 --server letsencrypt \
    --certificate-profile shortlived --days 6 --force
  ~/.acme.sh/acme.sh --installcert -d "$IP" --key-file /root/cert/ip/privkey.pem \
    --fullchain-file /root/cert/ip/fullchain.pem --reloadcmd "systemctl restart nazorat-relay" || true
fi

umask 077
echo "NAZORAT_KEYS=$KEYS" > /etc/nazorat.env
cat > /etc/systemd/system/nazorat-relay.service <<UNIT
[Unit]
Description=Nazorat relay (live screen view)
After=network-online.target

[Service]
EnvironmentFile=/etc/nazorat.env
ExecStart=/usr/local/bin/nazorat-relay
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable nazorat-relay
systemctl restart nazorat-relay
command -v ufw >/dev/null && { ufw allow 8443/tcp; ufw allow 8088/tcp; }
sleep 2
systemctl --no-pager status nazorat-relay | head -5
echo "NAZORAT OK"

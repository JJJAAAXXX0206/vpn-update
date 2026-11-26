#!/bin/bash
# Removes the Nazorat relay from the server completely (VPN / 3x-ui untouched).
systemctl disable --now nazorat-relay 2>/dev/null
rm -f /etc/systemd/system/nazorat-relay.service /etc/nazorat.env /usr/local/bin/nazorat-relay /root/nazorat-install.log /root/i.sh
systemctl daemon-reload
command -v ufw >/dev/null && { ufw delete allow 8443/tcp; ufw delete allow 8088/tcp; }
IP=$(curl -fsS4 https://api.ipify.org || hostname -I | awk '{print $1}')
[ -x /root/.acme.sh/acme.sh ] && /root/.acme.sh/acme.sh --remove -d "$IP" --ecc
rm -rf "/root/.acme.sh/${IP}_ecc" "/root/.acme.sh/${IP}" /root/cert/ip
systemctl is-active x-ui
echo "NAZORAT REMOVED"

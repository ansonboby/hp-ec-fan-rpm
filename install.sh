#!/bin/bash
# One-shot installer for the hp-ec-fan-rpm publisher.
# Loads ec_sys read-only and enables the systemd unit at boot.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo"; exit 1; }

modprobe ec_sys   # no write_support: EC access stays read-only
mkdir -p /etc/modules-load.d
grep -qx ec_sys /etc/modules-load.d/hp-ec-fan.conf 2>/dev/null || echo ec_sys >/etc/modules-load.d/hp-ec-fan.conf

install -m 0755 hp-ec-fan-rpm /usr/local/bin/hp-ec-fan-rpm
install -m 0644 hp-ec-fan-rpm.service /etc/systemd/system/hp-ec-fan-rpm.service
systemctl daemon-reload
systemctl enable --now hp-ec-fan-rpm.service
sleep 2
echo "/run/hp-fan-rpm = $(cat /run/hp-fan-rpm 2>/dev/null || echo missing)"

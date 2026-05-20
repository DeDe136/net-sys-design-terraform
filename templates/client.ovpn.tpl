# ──────────────────────────────────────────────────────────────────
# templates/client.ovpn.tpl
# Template file .ovpn cho Client VPN.
# Sau khi terraform apply, lấy giá trị từ output và điền vào:
#   terraform output -raw client_vpn_dns
#
# Cách tạo file .ovpn hoàn chỉnh:
#   bash scripts/generate_ovpn.sh
# ──────────────────────────────────────────────────────────────────

client
dev tun
proto udp
remote ${vpn_endpoint_dns} 443
remote-random-hostname
resolv-retry infinite
nobind
remote-cert-tls server
cipher AES-256-GCM
verb 3
reneg-sec 0

<ca>
${ca_cert}
</ca>

<cert>
${client_cert}
</cert>

<key>
${client_key}
</key>

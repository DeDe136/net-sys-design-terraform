# ──────────────────────────────────────────────────────────────────
# templates/client.ovpn.tpl
# Template cho AWS Client VPN (mutual TLS + Active Directory).
# ──────────────────────────────────────────────────────────────────

client
dev tun
proto udp
remote ${vpn_endpoint_dns} 443
remote-random-hostname
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3
reneg-sec 0
auth-user-pass

<ca>
${ca_cert}
</ca>

<cert>
${client_cert}
</cert>

<key>
${client_key}
</key>

#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# scripts/generate_ovpn.sh
# Tạo file .ovpn từ terraform output + certs đã tạo ở bước trước.
#
# Yêu cầu: terraform output đã có giá trị (sau apply)
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

PKI_DIR="/tmp/easy-rsa/easyrsa3/pki"
OUTPUT_FILE="client-vpn.ovpn"
TEMPLATE_FILE="templates/client.ovpn.tpl"

VPN_DNS=$(terraform output -raw client_vpn_dns)

CA_CERT=$(cat "${PKI_DIR}/ca.crt")
CLIENT_CERT=$(cat "${PKI_DIR}/issued/vpn-client.crt")
CLIENT_KEY=$(cat "${PKI_DIR}/private/vpn-client.key")

sed \
  -e "s|\${vpn_endpoint_dns}|${VPN_DNS}|g" \
  "${TEMPLATE_FILE}" > "${OUTPUT_FILE}"

# Append certs
{
  echo ""
  echo "<ca>"
  echo "${CA_CERT}"
  echo "</ca>"
  echo ""
  echo "<cert>"
  echo "${CLIENT_CERT}"
  echo "</cert>"
  echo ""
  echo "<key>"
  echo "${CLIENT_KEY}"
  echo "</key>"
} >> "${OUTPUT_FILE}"

echo "[OK] File .ovpn tạo tại: ${OUTPUT_FILE}"
echo "Chia sẻ file này cho remote staff để kết nối VPN."

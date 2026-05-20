#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# scripts/generate_vpn_certs.sh
# Tạo self-signed certificates cho Client VPN bằng easy-rsa,
# rồi import vào AWS ACM.
#
# Yêu cầu: git, easy-rsa (hoặc sẽ được clone tự động)
#
# Cách dùng:
#   chmod +x scripts/generate_vpn_certs.sh
#   bash scripts/generate_vpn_certs.sh
#
# Sau khi chạy xong, set 2 biến môi trường:
#   export TF_VAR_vpn_server_certificate_arn="arn:aws:acm:..."
#   export TF_VAR_vpn_client_certificate_arn="arn:aws:acm:..."
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

REGION="us-east-1"
CA_NAME="vpn-ca"
SERVER_NAME="vpn-server"
CLIENT_NAME="vpn-client"
EASYRSA_DIR="/tmp/easy-rsa"
PKI_DIR="${EASYRSA_DIR}/pki"

# ── Clone easy-rsa nếu chưa có ───────────────────────────────────
if [ ! -d "${EASYRSA_DIR}" ]; then
  git clone https://github.com/OpenVPN/easy-rsa.git "${EASYRSA_DIR}"
fi

cd "${EASYRSA_DIR}/easyrsa3"

# ── Khởi tạo PKI ─────────────────────────────────────────────────
./easyrsa init-pki
echo "set_var EASYRSA_BATCH 1" > pki/vars

# ── Build CA ──────────────────────────────────────────────────────
./easyrsa --batch build-ca nopass <<< "${CA_NAME}"

# ── Server certificate ────────────────────────────────────────────
./easyrsa --batch build-server-full "${SERVER_NAME}" nopass

# ── Client certificate ────────────────────────────────────────────
./easyrsa --batch build-client-full "${CLIENT_NAME}" nopass

echo "[OK] Certificates generated in ${PKI_DIR}"

# ── Import to ACM ─────────────────────────────────────────────────
echo "[IMPORT] Server certificate → ACM"
SERVER_ARN=$(aws acm import-certificate \
  --certificate fileb://"${PKI_DIR}/issued/${SERVER_NAME}.crt" \
  --private-key fileb://"${PKI_DIR}/private/${SERVER_NAME}.key" \
  --certificate-chain fileb://"${PKI_DIR}/ca.crt" \
  --region "${REGION}" \
  --query CertificateArn --output text)

echo "[IMPORT] Client (root CA) certificate → ACM"
CLIENT_ARN=$(aws acm import-certificate \
  --certificate fileb://"${PKI_DIR}/ca.crt" \
  --private-key fileb://"${PKI_DIR}/private/ca.key" \
  --region "${REGION}" \
  --query CertificateArn --output text)

echo ""
echo "=== Import hoàn tất ==="
echo "Chạy lệnh sau trước khi terraform apply:"
echo ""
echo "  export TF_VAR_vpn_server_certificate_arn=\"${SERVER_ARN}\""
echo "  export TF_VAR_vpn_client_certificate_arn=\"${CLIENT_ARN}\""
echo ""
echo "Hoặc thêm vào terraform.tfvars:"
echo "  vpn_server_certificate_arn = \"${SERVER_ARN}\""
echo "  vpn_client_certificate_arn = \"${CLIENT_ARN}\""

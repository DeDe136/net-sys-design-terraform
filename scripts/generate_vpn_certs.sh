#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# scripts/generate_vpn_certs.sh
# Tạo self-signed certificates cho AWS Client VPN bằng easy-rsa,
# rồi import vào AWS ACM bằng AWS CLI.
#
# Yêu cầu: git, aws cli (đã cấu hình credentials)
#
# Cách dùng:
#   chmod +x scripts/generate_vpn_certs.sh
#   bash scripts/generate_vpn_certs.sh
#
# Sau khi chạy xong, ARN được ghi tự động vào secret.tfvars.
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SECRET_FILE="${ROOT_DIR}/secret.tfvars"

REGION="us-east-1"

# FQDN — bắt buộc phải có dạng domain để AWS ACM chấp nhận
CA_CN="vpn.internal"
SERVER_CN="server.vpn.internal"
CLIENT_CN="client.vpn.internal"

EASYRSA_DIR="/tmp/easy-rsa"
PKI_DIR="${EASYRSA_DIR}/easyrsa3/pki"

# ── Kiểm tra AWS CLI ──────────────────────────────────────────────
if ! command -v aws &>/dev/null; then
  echo "ERROR: Không tìm thấy AWS CLI."
  echo "Cài đặt: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
  exit 1
fi

echo "[CHECK] AWS identity:"
aws sts get-caller-identity --region "$REGION"
echo ""

# ── Clone easy-rsa nếu chưa có ───────────────────────────────────
if [[ ! -d "${EASYRSA_DIR}" ]]; then
  echo "[CLONE] Đang clone easy-rsa..."
  git clone --depth=1 https://github.com/OpenVPN/easy-rsa.git "${EASYRSA_DIR}"
fi

cd "${EASYRSA_DIR}/easyrsa3"

# ── Khởi tạo PKI ─────────────────────────────────────────────────
echo "[PKI] Khởi tạo PKI..."
./easyrsa init-pki

cat > pki/vars <<EOF
set_var EASYRSA_BATCH        1
set_var EASYRSA_DN           "cn_only"
set_var EASYRSA_REQ_CN       "${CA_CN}"
EOF

# ── Build CA với CN = vpn.internal ───────────────────────────────
echo "[CA] Tạo Root CA (CN=${CA_CN})..."
./easyrsa --batch build-ca nopass

# ── Server certificate với CN = server.vpn.internal ──────────────
echo "[CERT] Tạo server certificate (CN=${SERVER_CN})..."
./easyrsa --batch build-server-full "${SERVER_CN}" nopass

# ── Client certificate với CN = client.vpn.internal ──────────────
echo "[CERT] Tạo client certificate (CN=${CLIENT_CN})..."
./easyrsa --batch build-client-full "${CLIENT_CN}" nopass

echo ""
echo "[OK] Certificates tạo xong tại: ${PKI_DIR}"

# ── Import Server cert vào ACM ────────────────────────────────────
echo "[IMPORT] Server certificate → ACM (region: ${REGION})..."
SERVER_ARN=$(aws acm import-certificate \
  --certificate  fileb://"${PKI_DIR}/issued/${SERVER_CN}.crt" \
  --private-key  fileb://"${PKI_DIR}/private/${SERVER_CN}.key" \
  --certificate-chain fileb://"${PKI_DIR}/ca.crt" \
  --region "$REGION" \
  --query CertificateArn \
  --output text)

echo "    Server ARN: ${SERVER_ARN}"

# ── Import Client cert vào ACM (dùng CA cert làm client cert) ────
echo "[IMPORT] Client certificate → ACM (region: ${REGION})..."
CLIENT_ARN=$(aws acm import-certificate \
  --certificate  fileb://"${PKI_DIR}/issued/${CLIENT_CN}.crt" \
  --private-key  fileb://"${PKI_DIR}/private/${CLIENT_CN}.key" \
  --certificate-chain fileb://"${PKI_DIR}/ca.crt" \
  --region "$REGION" \
  --query CertificateArn \
  --output text)

echo "    Client ARN: ${CLIENT_ARN}"

# ── Ghi ARN vào secret.tfvars ────────────────────────────────────
if [[ ! -f "$SECRET_FILE" ]]; then
  echo "WARNING: Không tìm thấy ${SECRET_FILE}, tạo mới..."
  touch "$SECRET_FILE"
fi

update_tfvar() {
  local KEY="$1"
  local VAL="$2"
  if grep -q "^${KEY}" "${SECRET_FILE}"; then
    sed -i.bak "s|^${KEY}.*|${KEY} = \"${VAL}\"|" "${SECRET_FILE}"
  else
    echo "${KEY} = \"${VAL}\"" >> "${SECRET_FILE}"
  fi
}

update_tfvar "vpn_server_certificate_arn" "$SERVER_ARN"
update_tfvar "vpn_client_certificate_arn" "$CLIENT_ARN"

echo ""
echo "════════════════════════════════════════"
echo " Import hoàn tất!"
echo "════════════════════════════════════════"
echo ""
echo "  vpn_server_certificate_arn = \"${SERVER_ARN}\""
echo "  vpn_client_certificate_arn = \"${CLIENT_ARN}\""
echo ""
echo "  → Đã ghi tự động vào: ${SECRET_FILE}"
echo ""
echo "Bước tiếp theo:"
echo "  terraform plan -var-file=\"secret.tfvars\" -var=\"enable_tgw_routes=false\" -out=tfplan"
echo "  terraform apply tfplan"
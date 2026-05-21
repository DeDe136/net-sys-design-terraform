#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# scripts/generate_ovpn.sh  (v2 — fix cert format)
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

PKI_DIR="/tmp/easy-rsa/easyrsa3/pki"
CLIENT_CN="client.vpn.internal"
OUTPUT_FILE="client-vpn.ovpn"
TEMPLATE_FILE="templates/client.ovpn.tpl"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cn)   CLIENT_CN="$2";   shift 2 ;;
    --out)  OUTPUT_FILE="$2"; shift 2 ;;
    --pki)  PKI_DIR="$2";     shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Validate ────────────────────────────────────────────────────────
echo "[CHECK] Kiểm tra prerequisites..."

[[ ! -f "${PKI_DIR}/ca.crt" ]] && \
  echo "ERROR: Không tìm thấy ${PKI_DIR}/ca.crt" && exit 1

[[ ! -f "${PKI_DIR}/issued/${CLIENT_CN}.crt" ]] && \
  echo "ERROR: Không tìm thấy ${PKI_DIR}/issued/${CLIENT_CN}.crt" && exit 1

[[ ! -f "${PKI_DIR}/private/${CLIENT_CN}.key" ]] && \
  echo "ERROR: Không tìm thấy ${PKI_DIR}/private/${CLIENT_CN}.key" && exit 1

[[ ! -f "${TEMPLATE_FILE}" ]] && \
  echo "ERROR: Template không tìm thấy: ${TEMPLATE_FILE}" && exit 1

# ── Lấy VPN DNS ─────────────────────────────────────────────────────
echo "[TERRAFORM] Lấy client_vpn_dns..."
VPN_DNS=$(terraform output -raw client_vpn_dns 2>/dev/null || true)
[[ -z "${VPN_DNS}" ]] && echo "ERROR: terraform output client_vpn_dns rỗng." && exit 1
echo "    VPN DNS: ${VPN_DNS}"

# ── Ghi VPN_DNS ra temp file (tránh shell injection) ─────────────────
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "${TMPDIR_WORK}"' EXIT

echo -n "${VPN_DNS}" > "${TMPDIR_WORK}/vpn_dns.txt"

# Strip easy-rsa metadata — chỉ lấy PEM block từ BEGIN đến END
awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' \
  "${PKI_DIR}/ca.crt" > "${TMPDIR_WORK}/ca.crt"

awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' \
  "${PKI_DIR}/issued/${CLIENT_CN}.crt" > "${TMPDIR_WORK}/client.crt"

cp "${PKI_DIR}/private/${CLIENT_CN}.key" "${TMPDIR_WORK}/client.key"

# ── Render bằng Python — đọc cert từ file, không qua heredoc ────────
echo "[RENDER] Tạo file .ovpn..."

python3 - "${TEMPLATE_FILE}" "${OUTPUT_FILE}" "${TMPDIR_WORK}" << 'PYEOF'
import sys, os

template_path = sys.argv[1]
output_path   = sys.argv[2]
tmp_dir       = sys.argv[3]

with open(template_path)                        as f: template  = f.read()
with open(f"{tmp_dir}/vpn_dns.txt")             as f: vpn_dns   = f.read().strip()
with open(f"{tmp_dir}/ca.crt")                  as f: ca_cert   = f.read().strip()
with open(f"{tmp_dir}/client.crt")              as f: client_cert = f.read().strip()
with open(f"{tmp_dir}/client.key")              as f: client_key  = f.read().strip()

replacements = {
    "${vpn_endpoint_dns}": vpn_dns,
    "${ca_cert}":          ca_cert,
    "${client_cert}":      client_cert,
    "${client_key}":       client_key,
}

content = template
for placeholder, value in replacements.items():
    if placeholder not in content:
        print(f"WARNING: '{placeholder}' không tìm thấy trong template.", file=sys.stderr)
    content = content.replace(placeholder, value)

# Strip comment header lines (bắt đầu bằng #)
lines = content.splitlines()
body = []
skip_header = True
for line in lines:
    # Bỏ qua các dòng comment (#) và dòng trống ở đầu file template
    if skip_header and (line.startswith("#") or line.strip() == ""):
        continue
    
    skip_header = False
    body.append(line)

# Kết quả cuối cùng: Join lại các dòng
final_content = "\n".join(body)

# Đảm bảo không có dòng trống thừa ở cuối file để tránh lỗi parsing
with open(output_path, "w") as f:
    f.write(final_content.strip() + "\n")

print(f"[OK] Đã ghi {len(content)} bytes → {output_path}")
PYEOF

# ── Verify ──────────────────────────────────────────────────────────
echo "[VERIFY] Kiểm tra file output..."
ERRORS=0

check() {
  local label="$1" pattern="$2"
  grep -q "${pattern}" "${OUTPUT_FILE}" \
    && echo "    ✓ ${label}" \
    || { echo "    ✗ MISSING: ${label}"; ERRORS=$((ERRORS+1)); }
}

check_absent() {
  local label="$1" pattern="$2"
  grep -q "${pattern}" "${OUTPUT_FILE}" \
    && { echo "    ✗ Còn placeholder: ${label}"; ERRORS=$((ERRORS+1)); } \
    || echo "    ✓ Không còn placeholder: ${label}"
}

check        "remote directive"      "^remote "
check        "VPN DNS trong remote"  "${VPN_DNS}"
check        "CA cert"               "BEGIN CERTIFICATE"
check        "Client cert"           "BEGIN CERTIFICATE"
check        "Client key"            "BEGIN.*PRIVATE KEY"
check        "ca block"              "^<ca>"
check        "cert block"            "^<cert>"
check        "key block"             "^<key>"
check_absent "\${ca_cert}"           '\${ca_cert}'
check_absent "\${client_cert}"       '\${client_cert}'
check_absent "\${client_key}"        '\${client_key}'

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "ERROR: File .ovpn có ${ERRORS} vấn đề. Xem lại."
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════"
echo " ✓  File .ovpn tạo thành công!"
echo "════════════════════════════════════════════════════"
echo ""
echo "  Output : ${OUTPUT_FILE}"
echo "  VPN DNS: ${VPN_DNS}"
echo "  Client : ${CLIENT_CN}"
echo ""
echo "Hướng dẫn cho staff:"
echo "  1. Cài AWS VPN Client: https://aws.amazon.com/vpn/client-vpn-download/"
echo "  2. File → Manage Profiles → Add Profile → chọn ${OUTPUT_FILE}"
echo "  3. Kết nối và nhập AD credentials (username / password)"
echo ""
echo "MULTI-USER — tạo cert riêng cho từng người:"
echo "  cd /tmp/easy-rsa/easyrsa3"
echo "  ./easyrsa build-client-full staff-alice nopass"
echo "  bash scripts/generate_ovpn.sh --cn staff-alice --out alice.ovpn"
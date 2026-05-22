#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# scripts/generate_ssh_keys.sh
#
# Sinh SSH key pairs cho toàn bộ hệ thống.
# Chạy script này MỘT LẦN trước khi terraform apply.
#
# Output:
#   ssh-keys/prod/bastion.pem  + bastion.pub
#   ssh-keys/prod/web.pem      + web.pub
#   ssh-keys/prod/erp.pem      + erp.pub
#   ssh-keys/rnd/rnd.pem       + rnd.pub
#
# Thư mục ssh-keys/ đã được gitignore — KHÔNG commit private keys.
#
# Luồng SSH sau khi apply Terraform:
#
#   [Production — qua SSM (không cần key)]
#   aws ssm start-session --target <bastion-instance-id>
#
#   [Production — qua SSH Agent Forwarding]
#   # Thêm key vào ssh-agent trên máy local:
#   ssh-add ssh-keys/prod/bastion.pem
#   ssh-add ssh-keys/prod/web.pem
#   ssh-add ssh-keys/prod/erp.pem
#
#   # Kết nối Client VPN, sau đó:
#   ssh -A ec2-user@<bastion_private_ip>        # vào Bastion (-A = agent forwarding)
#   ssh ec2-user@<web_private_ip>               # từ Bastion → Web (dùng web key qua agent)
#   ssh ec2-user@<erp_private_ip>               # từ Bastion → ERP (dùng erp key qua agent)
#
#   [R&D — SSH trực tiếp qua Client VPN]
#   ssh -i ssh-keys/rnd/rnd.pem ec2-user@<rnd_private_ip>
#
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSH_KEYS_DIR="$PROJECT_ROOT/ssh-keys"

# ── Màu sắc cho output ────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  SSH Key Pair Generator — AWS Infrastructure${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
echo ""

# ── Kiểm tra ssh-keygen ───────────────────────────────────────────
if ! command -v ssh-keygen &>/dev/null; then
  echo -e "${RED}ERROR: ssh-keygen không tìm thấy. Cài OpenSSH trước.${NC}"
  exit 1
fi

# ── Tạo thư mục ssh-keys ─────────────────────────────────────────
mkdir -p "$SSH_KEYS_DIR/prod"
mkdir -p "$SSH_KEYS_DIR/rnd"

# Quyền hạn chế truy cập thư mục
chmod 700 "$SSH_KEYS_DIR"
chmod 700 "$SSH_KEYS_DIR/prod"
chmod 700 "$SSH_KEYS_DIR/rnd"

# ── Hàm sinh key pair ─────────────────────────────────────────────
generate_key() {
  local name="$1"        # Tên key (bastion, web, erp, rnd)
  local dir="$2"         # Thư mục đích (ssh-keys/prod hoặc ssh-keys/rnd)
  local comment="$3"     # Comment cho public key
  local key_path="$dir/$name"

  if [[ -f "${key_path}.pem" ]]; then
    echo -e "${YELLOW}  [SKIP] ${key_path}.pem đã tồn tại — bỏ qua (xoá file nếu muốn tạo mới)${NC}"
    return 0
  fi

  echo -e "  ${GREEN}[GEN]${NC}  Đang tạo key: ${key_path}.pem"

  # Sinh ED25519 key (nhanh, an toàn hơn RSA 2048)
  ssh-keygen \
    -t ed25519 \
    -C "$comment" \
    -f "${key_path}" \
    -N "" \
    -q

  # Đổi tên file private key thành .pem để nhất quán
  mv "${key_path}" "${key_path}.pem"

  # Giữ nguyên file .pub (public key — dùng cho Terraform)

  # Quyền hạn chế
  chmod 600 "${key_path}.pem"
  chmod 644 "${key_path}.pub"

  echo -e "         Private: ${key_path}.pem"
  echo -e "         Public:  ${key_path}.pub"
}

# ── Production Key Pairs ──────────────────────────────────────────
echo -e "\n${BLUE}[Production]${NC}"

generate_key "bastion" "$SSH_KEYS_DIR/prod" \
  "prod-bastion-$(date +%Y%m%d)"

generate_key "web" "$SSH_KEYS_DIR/prod" \
  "prod-web-portal-$(date +%Y%m%d)"

generate_key "erp" "$SSH_KEYS_DIR/prod" \
  "prod-erp-crm-$(date +%Y%m%d)"

# ── R&D Key Pairs ─────────────────────────────────────────────────
echo -e "\n${BLUE}[R&D]${NC}"

generate_key "rnd" "$SSH_KEYS_DIR/rnd" \
  "rnd-testing-$(date +%Y%m%d)"

# ── Tóm tắt ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Key pairs đã sẵn sàng!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Bước tiếp theo:${NC}"
echo "  1. Chạy Terraform:"
echo "     terraform plan  -var-file=\"secret.tfvars\""
echo "     terraform apply -var-file=\"secret.tfvars\""
echo ""
echo "  2. SSH vào Bastion (qua SSM — không cần VPN):"
echo "     aws ssm start-session --target <bastion-instance-id>"
echo ""
echo "  3. SSH vào Bastion (qua Client VPN + SSH):"
echo "     ssh-add ssh-keys/prod/bastion.pem"
echo "     ssh-add ssh-keys/prod/web.pem"
echo "     ssh-add ssh-keys/prod/erp.pem"
echo "     ssh -A ec2-user@<bastion_private_ip>"
echo ""
echo "  4. Từ Bastion → SSH vào Web/ERP:"
echo "     ssh ec2-user@<web_private_ip>   # key web forwarded từ agent"
echo "     ssh ec2-user@<erp_private_ip>   # key erp forwarded từ agent"
echo ""
echo "  5. R&D staff SSH trực tiếp (qua Client VPN):"
echo "     ssh -i ssh-keys/rnd/rnd.pem ec2-user@<rnd_private_ip>"
echo ""
echo -e "${RED}⚠ QUAN TRỌNG: KHÔNG commit thư mục ssh-keys/ lên Git!${NC}"
echo "  Thư mục này đã được thêm vào .gitignore."
echo ""
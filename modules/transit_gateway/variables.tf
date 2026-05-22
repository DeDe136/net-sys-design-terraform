variable "prod_vpc_id" { type = string }
variable "rnd_vpc_id"  { type = string }

variable "create_tgw" {
  type        = bool
  default     = true
  description = "Set true to create a new TGW. Set false to only create attachments (use existing_tgw_id)."
}

variable "existing_tgw_id" {
  type        = string
  default     = ""
  description = "ID of an existing TGW — only needed when create_tgw = false."
}

variable "prod_private_subnet_ids" {
  type    = list(string)
  default = []
}
variable "rnd_private_subnet_ids" {
  type    = list(string)
  default = []
}

variable "create_prod_attachment" {
  type        = bool
  default     = true
  description = "Set true to create TGW attachment for Production VPC. Set false to skip."
}

variable "create_rnd_attachment" {
  type        = bool
  default     = true
  description = "Set true to create TGW attachment for R&D VPC. Set false to skip."
}

# ── VPN Client CIDR ───────────────────────────────────────────────
# Cần để tạo static route trong TGW default route table:
#   172.16.0.0/22 → Prod VPC attachment
# Client VPN nằm trong Prod VPC, nên reply từ R&D về VPN client
# phải đi qua TGW → Prod attachment → Client VPN endpoint.
# Nếu không có route này, TGW drop packet reply → SSH timeout.
variable "vpn_cidr" {
  type        = string
  default     = null
  description = "Client VPN CIDR (ví dụ: 172.16.0.0/22). Tạo static route trong TGW RT → Prod attachment."
}

variable "enable_tgw_routes" {
  type        = bool
  default     = false
  description = "Tạo TGW static route sau khi attachments đã available (lần apply thứ 2)."
}

variable "prod_vpc_id" { type = string }
variable "rnd_vpc_id"  { type = string }

variable "create_tgw" {
  type        = bool
  default     = true
  description = "Đặt true khi tạo TGW lần đầu. Đặt false khi chỉ tạo attachments (dùng existing_tgw_id)."
}

variable "existing_tgw_id" {
  type        = string
  default     = ""
  description = "ID của TGW đã tạo sẵn — chỉ cần khi create_tgw = false."
}

variable "prod_private_subnet_ids" {
  type    = list(string)
  default = []
}
variable "rnd_private_subnet_ids" {
  type    = list(string)
  default = []
}

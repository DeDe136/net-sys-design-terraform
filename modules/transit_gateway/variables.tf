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

variable "client_cidr"             { type = string }
variable "target_subnet_id"        { type = string }
variable "vpc_id"                  { type = string }
variable "name"                    { type = string }
variable "server_certificate_arn"  {
  type        = string
  description = "ACM ARN for the VPN server certificate"
  default     = ""
}
variable "client_certificate_arn"  {
  type        = string
  description = "ACM ARN for the client root certificate"
  default     = ""
}

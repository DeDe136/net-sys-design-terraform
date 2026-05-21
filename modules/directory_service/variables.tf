variable "name" {
  type        = string
  description = "Tag name for the directory"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy the directory into"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Exactly 2 subnet IDs in different AZs (db_subnet_1a + db_subnet_1b)"
}

variable "directory_name" {
  type        = string
  description = "Fully qualified domain name, e.g. corp.example.com"
  default     = "corp.example.com"
}

variable "directory_short_name" {
  type        = string
  description = "NetBIOS short name, e.g. CORP"
  default     = "CORP"
}

variable "directory_password" {
  type        = string
  sensitive   = true
  description = "Password for the directory administrator"
}

variable "edition" {
  type        = string
  description = "MicrosoftAD edition: Standard or Enterprise"
  default     = "Standard"
}
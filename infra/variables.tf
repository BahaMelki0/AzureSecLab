variable "subscription_id" {
  type = string
}
variable "location" {
  type    = string
  default = "francecentral"
}
variable "prefix" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{5,15}$", var.prefix))
    error_message = "Use 6-16 lowercase letters/digits; choose a globally unique prefix."
  }
}
variable "operator_ipv4" {
  type = string
  validation {
    condition     = can(cidrnetmask("${var.operator_ipv4}/32"))
    error_message = "Supply your public IPv4 address without a CIDR suffix."
  }
}
variable "ssh_public_key" {
  type = string
  validation {
    condition     = startswith(var.ssh_public_key, "ssh-")
    error_message = "Supply an SSH public key, never a private key."
  }
}
variable "security_mode" {
  type    = string
  default = "hardened"
  validation {
    condition     = contains(["hardened", "vulnerable"], var.security_mode)
    error_message = "Choose hardened or vulnerable."
  }
}
variable "acknowledge_lab_risk" {
  type    = bool
  default = false
}
variable "enable_sentinel" {
  type    = bool
  default = false
}
variable "secrets_seeded" {
  description = "Set true only after scripts.seed has created both synthetic secrets."
  type        = bool
  default     = false
}

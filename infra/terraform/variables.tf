variable "region" {
  type    = string
  default = "us-east-1"
}
variable "project_name" {
  type    = string
  default = "cdy2204-semana3"
}
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "allowed_api_cidr" {
  type        = string
  description = "IP publica autorizada. Ejemplo: 203.0.113.10/32."
  validation {
    condition     = can(cidrhost(var.allowed_api_cidr, 0)) && var.allowed_api_cidr != "0.0.0.0/0"
    error_message = "Definir una CIDR valida y restringida; no 0.0.0.0/0."
  }
}
variable "github_repo" {
  type        = string
  description = "Cuenta/repositorio de GitHub (owner/repo)"
}
variable "github_environment" {
  type    = string
  default = "aws-demo"
}

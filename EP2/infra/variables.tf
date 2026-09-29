variable "aws_region" {
  description = "Región del Learner Lab."
  type        = string
  default     = "us-east-1"
}

variable "admin_cidr" {
  description = <<-EOT
    Desde dónde se accede por IP pública a SSH, Grafana, Prometheus y la plataforma.
    Por defecto, cualquier origen. Para restringirlo a un equipo: "x.x.x.x/32".
    Los exporters (9100, 9187) nunca se abren aquí: solo desde andys-monitoreo.
  EOT
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr debe ser un CIDR válido, por ejemplo 200.83.12.45/32."
  }
}

variable "instance_type_plataforma" {
  description = "6 APIs Node.js + PostgreSQL + HAProxy + exporters."
  type        = string
  default     = "t3.medium"
}

variable "instance_type_monitoreo" {
  description = "Prometheus + Grafana."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Par de llaves del Learner Lab."
  type        = string
  default     = "vockey"
}

variable "root_volume_size" {
  description = "Disco raíz en GB (imágenes Docker y datos)."
  type        = number
  default     = 20
}

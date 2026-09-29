variable "aws_region" {
  description = "Región del Learner Lab."
  type        = string
  default     = "us-east-1"
}

variable "tfstate_bucket" {
  description = "Bucket S3 del estado de Terraform (andys-tfstate-<cuenta>). Lo entrega el workflow."
  type        = string
}

variable "project_name" {
  description = "Prefijo de los recursos de esta capa."
  type        = string
  default     = "andys"
}

variable "plataforma_project_name" {
  description = "project_name con el que se desplegó la plataforma del docente (prefijo de sus SG)."
  type        = string
  default     = "andys-motors"
}

variable "admin_cidr" {
  description = "IP pública del administrador en formato /32. Accede a SSH, Grafana y Prometheus."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr debe ser un CIDR válido, por ejemplo 200.83.12.45/32."
  }
}

variable "instance_type" {
  description = "Tipo de instancia para Prometheus + Grafana."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Par de llaves del Learner Lab."
  type        = string
  default     = "vockey"
}

variable "root_volume_size" {
  description = "Disco raíz en GB (imágenes Docker + TSDB de Prometheus)."
  type        = number
  default     = 20
}

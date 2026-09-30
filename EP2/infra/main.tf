# ─────────────────────────────────────────────────────────────
# EP2 · Infraestructura AndysMotors en AWS Academy Learner Lab
#
# Solo red y cómputo: dos EC2 Ubuntu 24.04 y sus Security Groups.
#   andys-plataforma  aquí se instala la plataforma AndysMotors
#                     (Casos/AndysMotors/demo del repositorio del docente)
#   andys-monitoreo   aquí se instalan Prometheus y Grafana
#
# Ambas máquinas arrancan con Docker Engine y Docker Compose instalados
# (scripts/instalar-docker.sh). Todo lo demás se instala a mano.
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # El bucket se entrega en "terraform init" con -backend-config porque su
  # nombre lleva el ID de la cuenta del lab. use_lockfile: bloqueo nativo de S3.
  backend "s3" {
    key          = "andys/ep2/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Proyecto   = "AndysMotors"
      Asignatura = "ADY1103"
      Evaluacion = "EP2"
      Gestionado = "Terraform"
    }
  }
}

# ── Recursos que ya existen en el Learner Lab ───────────────────────────────

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# El lab no permite crear roles de IAM: se usa el perfil que ya trae.
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

locals {
  # Las dos instancias en la misma subred: el scraping no cruza zonas.
  subnet_id = sort(data.aws_subnets.default.ids)[0]

  # Puertos de la plataforma que el monitoreo necesita alcanzar.
  puertos_scraping = {
    "sitio web (HAProxy, generador de trafico)" = 80
    "web-api /metrics"                          = 8081
    "stock-api /metrics"                        = 8082
    "agenda-api /metrics"                       = 8083
    "crm-api /metrics"                          = 8084
    "pagos-api /metrics"                        = 8085
    "gateway-externo /metrics"                  = 8086
    "HAProxy /metrics"                          = 8404
    "node-exporter"                             = 9100
    "postgres-exporter"                         = 9187
  }

  # Puertos de la plataforma accesibles por IP publica (var.admin_cidr).
  puertos_admin_plataforma = {
    "SSH"                         = 22
    "sitio web publico"           = 80
    "portales internos 8081-8086" = null
    "HAProxy /stats y /metrics"   = 8404
  }
}

# ── Security Group: monitoreo ───────────────────────────────────────────────

resource "aws_security_group" "monitoreo" {
  name        = "andys-monitoreo-sg"
  description = "Prometheus y Grafana de AndysMotors"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "andys-monitoreo-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "monitoreo_admin" {
  for_each = {
    "SSH"        = 22
    "Grafana"    = 3000
    "Prometheus" = 9090
  }

  security_group_id = aws_security_group.monitoreo.id
  description       = "${each.key} por IP publica"
  cidr_ipv4         = var.admin_cidr
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "monitoreo_salida" {
  security_group_id = aws_security_group.monitoreo.id
  description       = "Salida a Internet (paquetes, imagenes) y scraping hacia la plataforma"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ── Security Group: plataforma ──────────────────────────────────────────────

resource "aws_security_group" "plataforma" {
  name        = "andys-plataforma-sg"
  description = "Plataforma AndysMotors: acceso por IP publica y scraping desde el monitoreo"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "andys-plataforma-sg" }
}

# Origen = SG de monitoreo (no una IP): la regla sigue valiendo aunque la
# instancia de monitoreo cambie de dirección o se recree.
resource "aws_vpc_security_group_ingress_rule" "plataforma_desde_monitoreo" {
  for_each = local.puertos_scraping

  security_group_id            = aws_security_group.plataforma.id
  description                  = "${each.key} desde andys-monitoreo"
  referenced_security_group_id = aws_security_group.monitoreo.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "plataforma_admin" {
  for_each = local.puertos_admin_plataforma

  security_group_id = aws_security_group.plataforma.id
  description       = "${each.key} por IP publica"
  cidr_ipv4         = var.admin_cidr
  from_port         = each.value == null ? 8081 : each.value
  to_port           = each.value == null ? 8086 : each.value
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "plataforma_salida" {
  security_group_id = aws_security_group.plataforma.id
  description       = "Salida a Internet (paquetes, imagenes Docker, GitHub)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ── Instancias ──────────────────────────────────────────────────────────────

resource "aws_instance" "plataforma" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_plataforma
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.plataforma.id]
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Instala Docker en el primer arranque. Si el script cambia, la instancia se
  # recrea: user_data solo se ejecuta una vez y, sin esto, el cambio no tendría efecto.
  user_data                   = file("${path.module}/scripts/instalar-docker.sh")
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2
  }

  tags = { Name = "andys-plataforma", Rol = "plataforma" }
}

resource "aws_instance" "monitoreo" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_monitoreo
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.monitoreo.id]
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Instala Docker en el primer arranque. Si el script cambia, la instancia se
  # recrea: user_data solo se ejecuta una vez y, sin esto, el cambio no tendría efecto.
  user_data                   = file("${path.module}/scripts/instalar-docker.sh")
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2
  }

  tags = { Name = "andys-monitoreo", Rol = "monitoreo" }
}

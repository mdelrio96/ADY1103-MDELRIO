# ─────────────────────────────────────────────────────────────
# EP2 · Capa de observabilidad de AndysMotors (AWS Academy Learner Lab)
#
# Crea la instancia andys-monitoreo, vacía salvo por Docker y Compose, donde se
# instalan Prometheus y Grafana a mano según el instrumento de la EP2. Además
# abre, en los Security Groups de la plataforma del docente, los puertos que el
# monitoreo necesita scrapear, siempre con origen en el SG de monitoreo.
#
# Depende de la capa "plataforma" (Terraform del docente): lee sus IP privadas
# desde el estado remoto y sus Security Groups por nombre. Por eso se aplica
# después de la plataforma y se destruye antes que ella.
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Configuración parcial: el bucket se pasa en "terraform init" con
  # -backend-config, porque su nombre lleva el ID de la cuenta del lab y cambia
  # si el lab se resetea. use_lockfile usa el bloqueo nativo de S3.
  backend "s3" {
    key          = "andys/monitoreo/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Proyecto   = var.project_name
      Asignatura = "ADY1103"
      Evaluacion = "EP2"
      Capa       = "observabilidad"
      Gestionado = "Terraform"
    }
  }
}

# ── Lo que ya existe: plataforma del docente y recursos del lab ─────────────

data "terraform_remote_state" "plataforma" {
  backend = "s3"
  config = {
    bucket = var.tfstate_bucket
    key    = "andys/plataforma/terraform.tfstate"
    region = var.aws_region
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Misma subred que usa la plataforma (primera en orden alfabético), para que el
# tráfico de scraping no cruce zonas de disponibilidad.
data "aws_subnet" "elegida" {
  id = sort(data.aws_subnets.default.ids)[0]
}

data "aws_security_group" "app" {
  name   = "${var.plataforma_project_name}-app-sg"
  vpc_id = data.aws_vpc.default.id
}

data "aws_security_group" "borde" {
  name   = "${var.plataforma_project_name}-borde-sg"
  vpc_id = data.aws_vpc.default.id
}

# El lab no permite crear roles de IAM: se usa el perfil que ya trae.
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ips_plataforma = data.terraform_remote_state.plataforma.outputs.ips_privadas

  # Puertos de la plataforma que Prometheus scrapea en el servidor "app".
  #   8081-8086  /metrics de web, stock, agenda, crm, pagos y gateway externo
  #   9100       node-exporter (se instala a mano)
  #   9187       postgres-exporter (se instala a mano)
  puertos_app = {
    web      = 8081
    stock    = 8082
    agenda   = 8083
    crm      = 8084
    pagos    = 8085
    gateway  = 8086
    node     = 9100
    postgres = 9187
  }

  # En el servidor "borde": 80 para el generador de tráfico, 8404 métricas de
  # HAProxy y 9100 node-exporter.
  puertos_borde = {
    http    = 80
    haproxy = 8404
    node    = 9100
  }
}

# ── Security Group del monitoreo ────────────────────────────────────────────

resource "aws_security_group" "monitoreo" {
  name        = "${var.project_name}-monitoreo-sg"
  description = "Prometheus y Grafana de AndysMotors: solo accesibles desde la IP del administrador"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "${var.project_name}-monitoreo-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "monitoreo_admin" {
  for_each = {
    ssh        = 22
    grafana    = 3000
    prometheus = 9090
  }

  security_group_id = aws_security_group.monitoreo.id
  description       = "${each.key} desde la IP del administrador"
  cidr_ipv4         = var.admin_cidr
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "monitoreo_salida" {
  security_group_id = aws_security_group.monitoreo.id
  description       = "Salida a Internet (imagenes Docker) y hacia la plataforma (scraping)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ── Reglas que se agregan a los SG de la plataforma ─────────────────────────
# Se referencian por ID de SG y no por IP: si la instancia de monitoreo se
# recrea, las reglas siguen siendo válidas.

resource "aws_vpc_security_group_ingress_rule" "app_desde_monitoreo" {
  for_each = local.puertos_app

  security_group_id            = data.aws_security_group.app.id
  description                  = "Scraping ${each.key} desde andys-monitoreo"
  referenced_security_group_id = aws_security_group.monitoreo.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "borde_desde_monitoreo" {
  for_each = local.puertos_borde

  security_group_id            = data.aws_security_group.borde.id
  description                  = "${each.key} desde andys-monitoreo"
  referenced_security_group_id = aws_security_group.monitoreo.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
}

# ── Instancia andys-monitoreo ───────────────────────────────────────────────

resource "aws_instance" "monitoreo" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.elegida.id
  vpc_security_group_ids      = [aws_security_group.monitoreo.id]
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Solo prepara la máquina. Prometheus y Grafana se instalan a mano.
  user_data = templatefile("${path.module}/templates/user_data_monitoreo.sh.tftpl", {
    ip_app   = local.ips_plataforma["app"]
    ip_borde = local.ips_plataforma["borde"]
  })
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

  tags = {
    Name = "${var.project_name}-monitoreo"
    Rol  = "monitoreo"
  }
}

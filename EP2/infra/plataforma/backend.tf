# Backend remoto para el Terraform del docente (Casos/AndysMotors/infra).
#
# El workflow copia este archivo junto al código del docente antes de
# "terraform init". El bucket se entrega con -backend-config porque lleva el ID
# de la cuenta del lab.
terraform {
  backend "s3" {
    key          = "andys/plataforma/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

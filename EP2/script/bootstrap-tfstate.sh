#!/bin/bash
# ============================================
# Crea el bucket S3 del estado de Terraform si no existe (idempotente).
#
# El nombre lleva el ID de la cuenta del lab: andys-tfstate-<cuenta>. Un reset
# del lab borra el bucket junto con todo lo demás; este script lo vuelve a crear
# y el siguiente apply parte con un estado vacío.
#
# No es un recurso de Terraform porque el backend lo necesita antes del init.
# El bloqueo usa el lockfile nativo de S3 (use_lockfile), sin DynamoDB.
#
# Imprime el nombre del bucket en la última línea (el workflow la lee).
#   ./EP2/script/bootstrap-tfstate.sh [region]
# ============================================
set -euo pipefail

REGION="${1:-us-east-1}"
command -v aws > /dev/null || { echo "Falta aws en el PATH"; exit 1; }

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="andys-tfstate-${ACCOUNT}"

if out="$(aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>&1)"; then
  echo "Bucket $BUCKET: ya existe." >&2
elif grep -q "(404)" <<< "$out"; then
  echo "Bucket $BUCKET: no existe; creando en $REGION..." >&2
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" > /dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
  fi
  aws s3api wait bucket-exists --bucket "$BUCKET" --region "$REGION"
  aws s3api put-bucket-versioning --bucket "$BUCKET" --region "$REGION" \
    --versioning-configuration Status=Enabled
  aws s3api put-public-access-block --bucket "$BUCKET" --region "$REGION" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  echo "Bucket $BUCKET: creado (versionado, acceso público bloqueado)." >&2
else
  echo "No se pudo consultar el bucket $BUCKET:" >&2
  echo "$out" >&2
  exit 1
fi

echo "$BUCKET"

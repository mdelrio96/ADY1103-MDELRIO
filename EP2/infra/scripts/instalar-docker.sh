#!/bin/bash
# ---------------------------------------------------------------------------
# Instalación de Docker Engine y Docker Compose en Ubuntu 24.04 (user_data).
#
# Usa el repositorio oficial de Docker (docs.docker.com/engine/install/ubuntu),
# no el paquete docker.io de Ubuntu, para tener el plugin "docker compose" v2.
# También sirve para una instancia ya creada:  sudo bash instalar-docker.sh
#
# Log: /var/log/cloud-init-output.log   ·   Fin: /home/ubuntu/.docker-listo
# ---------------------------------------------------------------------------
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Dependencias (git y python3 para clonar el caso y generar tráfico).
apt-get update -y
apt-get install -y ca-certificates curl git python3 jq

# 2. Llave GPG y repositorio oficial de Docker.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

# 3. Docker Engine, Buildx y Compose v2.
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Rotación de logs de los contenedores: sin esto crecen sin límite y llenan el disco.
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON

# 5. Arranque automático al encender la instancia (el lab la detiene al cerrar la sesión).
systemctl enable docker containerd
systemctl restart docker

# 6. El usuario ubuntu usa docker sin sudo (aplica desde el próximo inicio de sesión).
usermod -aG docker ubuntu

docker --version
docker compose version
touch /home/ubuntu/.docker-listo
chown ubuntu:ubuntu /home/ubuntu/.docker-listo

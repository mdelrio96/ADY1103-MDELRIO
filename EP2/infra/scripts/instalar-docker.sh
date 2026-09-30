#!/bin/bash
# ---------------------------------------------------------------------------
# Instalación de Docker Engine y Docker Compose en Ubuntu 24.04.
#
# Terraform lo ejecuta por SSH durante el apply (terraform_data.docker en
# main.tf): la instancia no se da por lista hasta que este script termina, y si
# falla, falla el apply. Es idempotente: se puede volver a ejecutar sin daño.
#
# Usa el repositorio oficial de Docker (docs.docker.com/engine/install/ubuntu),
# no el paquete docker.io de Ubuntu, para tener el plugin "docker compose" v2.
# El usuario ubuntu queda en el grupo docker: docker y docker compose sin sudo.
#
# A mano en una instancia existente:  sudo bash instalar-docker.sh
# ---------------------------------------------------------------------------
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
USUARIO=ubuntu
# Al arrancar, Ubuntu puede estar usando apt (actualizaciones automáticas):
# se espera hasta 5 minutos por el bloqueo en vez de fallar.
APT="apt-get -o DPkg::Lock::Timeout=300"

# 1. Grupo docker y usuario ubuntu dentro de él. El paquete docker-ce reutiliza
#    este grupo para el socket /var/run/docker.sock.
groupadd -f --system docker
usermod -aG docker "$USUARIO"

# 2. Dependencias (git y python3 para clonar el caso y generar tráfico).
$APT update -y
$APT install -y ca-certificates curl git python3 jq

# 3. Llave GPG y repositorio oficial de Docker.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

# 4. Docker Engine, Buildx y Compose v2.
$APT update -y
$APT install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Rotación de logs de los contenedores: sin esto crecen sin límite y llenan el disco.
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON

# 6. Arranque automático al encender la instancia (el lab la detiene al cerrar la sesión).
systemctl enable docker containerd
systemctl restart docker

# 7. Comprobación: ubuntu usa docker sin sudo.
stat -c '%U:%G %a %n' /var/run/docker.sock
sudo -u "$USUARIO" -g docker docker version
docker compose version

touch "/home/$USUARIO/.docker-listo"
chown "$USUARIO:$USUARIO" "/home/$USUARIO/.docker-listo"

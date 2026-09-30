#!/bin/bash
# ---------------------------------------------------------------------------
# Instalación de Docker Engine y Docker Compose en Ubuntu 24.04 (user_data).
#
# Usa el repositorio oficial de Docker (docs.docker.com/engine/install/ubuntu),
# no el paquete docker.io de Ubuntu, para tener el plugin "docker compose" v2.
# El usuario ubuntu queda en el grupo docker: docker y docker compose sin sudo.
# También sirve para una instancia ya creada:  sudo bash instalar-docker.sh
#
# Log: /var/log/cloud-init-output.log   ·   Fin: /home/ubuntu/.docker-listo
# ---------------------------------------------------------------------------
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
USUARIO=ubuntu

# 1. Grupo docker y usuario ubuntu dentro de él, ANTES de instalar nada.
#    Un grupo solo se aplica a las sesiones que se abren después de asignarlo:
#    hacerlo al inicio achica la ventana en que una sesión SSH queda sin él.
#    El paquete docker-ce reutiliza este grupo para el socket /var/run/docker.sock.
groupadd -f --system docker
usermod -aG docker "$USUARIO"

# 2. Aviso al iniciar sesión: indica si Docker sigue instalándose o si la sesión
#    se abrió antes de tener el grupo.
cat > /etc/profile.d/docker-estado.sh <<'AVISO'
if [ "$(id -un)" = "ubuntu" ]; then
  if [ ! -f /home/ubuntu/.docker-listo ]; then
    echo "[docker] Instalándose (unos 2 minutos). Progreso: sudo tail -f /var/log/cloud-init-output.log"
  elif ! id -nG | grep -qw docker; then
    echo "[docker] Listo, pero esta sesión no tiene el grupo docker: ejecuta 'newgrp docker' o vuelve a conectarte."
  fi
fi
AVISO

# 3. Dependencias (git y python3 para clonar el caso y generar tráfico).
apt-get update -y
apt-get install -y ca-certificates curl git python3 jq

# 4. Llave GPG y repositorio oficial de Docker.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

# 5. Docker Engine, Buildx y Compose v2.
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Rotación de logs de los contenedores: sin esto crecen sin límite y llenan el disco.
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON

# 7. Arranque automático al encender la instancia (el lab la detiene al cerrar la sesión).
systemctl enable docker containerd
systemctl restart docker

# 8. Comprobación: el socket debe pertenecer al grupo docker y ubuntu debe poder usarlo.
stat -c '%U:%G %a %n' /var/run/docker.sock
sudo -u "$USUARIO" -g docker docker version
docker compose version

touch "/home/$USUARIO/.docker-listo"
chown "$USUARIO:$USUARIO" "/home/$USUARIO/.docker-listo"

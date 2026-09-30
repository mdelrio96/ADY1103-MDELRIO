# ADY1103 · Monitoreo y Observabilidad — Marcelo del Río

Repositorio de trabajo de la **Evaluación Parcial 2** (caso AndysMotors): stack de observabilidad
Open Source con Prometheus y Grafana sobre AWS Academy Learner Lab.

## Estructura

```
.github/workflows/infraestructura.yaml   # Run workflow: apply | plan | destroy
EP2/infra/                               # Terraform: 2 EC2 + Security Groups (lo usa el workflow)
EP2/infra/scripts/instalar-docker.sh     # Docker Engine + Compose, ejecutado por SSH en el apply
EP2/plataforma/exporters/                # node-exporter + postgres-exporter  → andys-plataforma
EP2/monitoreo/                           # Prometheus + Grafana               → andys-monitoreo
EP2/monitoreo/prometheus/prometheus.yml  # configuración de recolección (entregable)
```

Las carpetas `plataforma/` y `monitoreo/` no las usa el workflow: se clonan y copian a mano en cada EC2.

## Infraestructura

El workflow crea red y cómputo. Ambas instancias son Ubuntu 24.04. Durante el `apply`, Terraform se
conecta por SSH a cada una y ejecuta [`EP2/infra/scripts/instalar-docker.sh`](EP2/infra/scripts/instalar-docker.sh):
cuando el workflow termina, Docker Engine y Docker Compose ya están listos y el usuario `ubuntu` los usa
sin `sudo`. La plataforma, los exporters y el stack de monitoreo se instalan a mano.

| Instancia | Tipo | Para qué |
|---|---|---|
| `andys-plataforma` | t3.medium | plataforma AndysMotors ([`Casos/AndysMotors/demo`](https://github.com/asanchezo-duoc/ADY1103-Activities/tree/main/Casos/AndysMotors/demo)) y exporters |
| `andys-monitoreo` | t3.small | Prometheus y Grafana |

### Puertos

| Security Group | Puerto | Origen | Uso |
|---|---|---|---|
| `andys-monitoreo-sg` | 22, 3000, 9090 | Internet | SSH, Grafana, Prometheus |
| `andys-plataforma-sg` | 22, 80, 8081–8086, 8404 | Internet | SSH, sitio, portales internos, HAProxy `/stats` |
| `andys-plataforma-sg` | 80 | `andys-monitoreo-sg` | generador de tráfico |
| `andys-plataforma-sg` | 8081–8086 | `andys-monitoreo-sg` | `/metrics` de web, stock, agenda, CRM, pagos y gateway |
| `andys-plataforma-sg` | 8404 | `andys-monitoreo-sg` | métricas de HAProxy |
| `andys-plataforma-sg` | 9100, 9187 | `andys-monitoreo-sg` | node-exporter, postgres-exporter |

Todo se accede con la IP pública de cada EC2. Para restringir el acceso a un solo equipo, cambiar
`admin_cidr` en `EP2/infra/variables.tf` (por ejemplo `"200.83.12.45/32"`).

El scraping usa el Security Group de monitoreo como origen, no una IP: las reglas siguen valiendo
aunque la instancia cambie de dirección. Los exporters (9100, 9187) no quedan expuestos a Internet.

## Configuración (una vez)

Settings → Secrets and variables → Actions:

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Learner Lab → AWS Details → AWS CLI. **Se actualizan en cada sesión del lab.** |
| `LAB_PEM` | contenido completo de `labsuser.pem` (AWS Details → Download PEM), desde `-----BEGIN` hasta `-----END ... KEY-----`. Se carga una vez. |

## Uso

1. Learner Lab → **Start Lab**; actualizar los tres secrets de AWS.
2. Actions → **EP2 · Infraestructura** → Run workflow → `apply`.
3. El resumen muestra IP públicas y privadas, comandos SSH y los targets de scraping.
4. Al terminar: detener las instancias o ejecutar el workflow con `destroy`.

Al cerrar la sesión del lab las instancias quedan detenidas; al encenderlas cambian las IP públicas y
se mantienen las privadas, que son las que usa `prometheus.yml`. Volver a correr `apply` no recrea
nada y muestra las IP públicas nuevas.

# ADY1103 · Monitoreo y Observabilidad — Marcelo del Río

Repositorio de trabajo de la **Evaluación Parcial 2** (caso AndysMotors): stack de observabilidad
Open Source con Prometheus y Grafana sobre AWS Academy Learner Lab.

## Estructura

```
.github/workflows/
  infraestructura.yaml   # Run workflow: apply | plan | destroy
EP2/
  infra/plataforma/      # backend y valores para el Terraform del docente
  infra/monitoreo/       # Terraform propio: EC2 andys-monitoreo + Security Groups
```

El estado de ambas capas se guarda en el bucket `andys-tfstate-<cuenta>`, que el propio workflow
crea si no existe.

## Infraestructura

El pipeline levanta tres instancias EC2:

| Instancia | Origen | Contenido |
|---|---|---|
| `andys-motors-app` | Terraform del docente ([ADY1103-Activities](https://github.com/asanchezo-duoc/ADY1103-Activities), `Casos/AndysMotors/infra`, topología `compacta`) | web, stock, agenda, CRM, pagos, gateway externo y PostgreSQL, con `/metrics` |
| `andys-motors-borde` | Terraform del docente | HAProxy: sitio público y métricas en `:8404` |
| `andys-monitoreo` | `EP2/infra/monitoreo` | Docker y Compose listos para instalar Prometheus y Grafana |

El código del docente se descarga en un commit fijo (`UPSTREAM_REF`) y no se modifica: solo se le
agrega el backend remoto y los valores de `EP2/infra/plataforma/plataforma.tfvars`. La capa de
monitoreo lee las IP privadas de la plataforma desde su estado y abre, en los Security Groups de la
plataforma, solo los puertos de scraping y con origen en el Security Group de monitoreo.

El pipeline **no** instala Prometheus, Grafana ni exporters: eso se hace a mano sobre
`andys-monitoreo`, como parte de la evaluación.

## Configuración (una vez)

**Secrets** (Settings → Secrets and variables → Actions):

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Learner Lab → AWS Details → AWS CLI. **Se actualizan en cada sesión del lab.** |
| `ADMIN_CIDR` | IP pública propia en formato `x.x.x.x/32` (<https://checkip.amazonaws.com>) |
| `DB_PASSWORD` | 12 a 41 caracteres: letras, números, `_ . ~ -` |
| `ANDYS_ADMIN_TOKEN` | token del panel `/admin/fallas` de la plataforma |

**Variable** opcional: `UPSTREAM_REF` = commit del repositorio del docente (por defecto `8add424`).

Con la CLI de GitHub:

```bash
gh secret set AWS_SESSION_TOKEN -R mdelrio96/ADY1103-MDELRIO
```

## Uso

1. Learner Lab → **Start Lab**; actualizar los tres secrets de AWS.
2. Actions → **EP2 · Infraestructura** → Run workflow → `apply`.
3. El resumen de la ejecución muestra la URL del sitio, las IP privadas de la plataforma (targets del
   `prometheus.yml`) y el comando SSH de `andys-monitoreo`.
4. Al terminar: detener las instancias o ejecutar el mismo workflow con `destroy`.

Tras cerrar la sesión del lab las instancias quedan detenidas y al encenderlas cambian las IP
públicas; las privadas se mantienen. Volver a correr `apply` no recrea nada si no hubo cambios y
actualiza las IP públicas en el resumen.

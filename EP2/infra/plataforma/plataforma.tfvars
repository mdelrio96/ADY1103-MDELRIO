# Valores para el Terraform del docente (sin secretos: esos llegan como TF_VAR_*
# desde los secrets del repositorio).

aws_region   = "us-east-1"
project_name = "andys-motors"

# Todas las plataformas en un servidor más el balanceador: 2 instancias.
# Con la EC2 de monitoreo propia quedan 3, dentro de la cuota del lab.
topologia     = "compacta"
instance_type = "t3.small"

# El stack de referencia del docente queda apagado: el monitoreo es el trabajo de la EP2.
enable_monitoring = false

# PostgreSQL corre como contenedor en el servidor de aplicación.
enable_rds = false

# El sitio queda accesible solo desde admin_cidr.
allow_public_web = false

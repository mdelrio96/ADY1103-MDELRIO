output "monitoreo_ip_publica" {
  description = "IP pública de andys-monitoreo. Cambia cada vez que el lab enciende la instancia."
  value       = aws_instance.monitoreo.public_ip
}

output "monitoreo_ip_privada" {
  description = "IP privada de andys-monitoreo."
  value       = aws_instance.monitoreo.private_ip
}

output "ssh" {
  description = "Conexión SSH (desde la carpeta donde está labsuser.pem)."
  value       = "ssh -i labsuser.pem ec2-user@${aws_instance.monitoreo.public_ip}"
}

output "grafana" {
  description = "URL de Grafana, una vez instalado."
  value       = "http://${aws_instance.monitoreo.public_ip}:3000"
}

output "prometheus" {
  description = "URL de Prometheus, una vez instalado."
  value       = "http://${aws_instance.monitoreo.public_ip}:9090"
}

output "targets_plataforma" {
  description = "Direcciones que se declaran como targets en prometheus.yml."
  value = merge(
    { for nombre, puerto in local.puertos_app : "app_${nombre}" => "${local.ips_plataforma["app"]}:${puerto}" if puerto != 80 },
    { for nombre, puerto in local.puertos_borde : "borde_${nombre}" => "${local.ips_plataforma["borde"]}:${puerto}" if puerto != 80 },
  )
}

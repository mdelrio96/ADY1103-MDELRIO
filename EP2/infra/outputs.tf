output "plataforma" {
  description = "andys-plataforma. La IP pública cambia al reencender la instancia; la privada no."
  value = {
    ip_publica = aws_instance.plataforma.public_ip
    ip_privada = aws_instance.plataforma.private_ip
    ssh        = "ssh -i labsuser.pem ubuntu@${aws_instance.plataforma.public_ip}"
    sitio      = "http://${aws_instance.plataforma.public_ip}"
  }
}

output "monitoreo" {
  description = "andys-monitoreo."
  value = {
    ip_publica = aws_instance.monitoreo.public_ip
    ip_privada = aws_instance.monitoreo.private_ip
    ssh        = "ssh -i labsuser.pem ubuntu@${aws_instance.monitoreo.public_ip}"
    grafana    = "http://${aws_instance.monitoreo.public_ip}:3000"
    prometheus = "http://${aws_instance.monitoreo.public_ip}:9090"
  }
}

output "targets_scraping" {
  description = "Direcciones que Prometheus alcanza en la plataforma (IP privada)."
  value       = { for nombre, puerto in local.puertos_scraping : nombre => "${aws_instance.plataforma.private_ip}:${puerto}" if puerto != 80 }
}

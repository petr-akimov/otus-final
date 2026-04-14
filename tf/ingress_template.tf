# ------------------------------------------------
# ГЕНЕРАЦИЯ ГОТОВОГО INGRESS-МАНИФЕСТА С STATIC IP
# ------------------------------------------------

data "template_file" "ingress_yaml" {
  template = file("${path.module}/../tf/templates/ingress.yaml.tmpl")

  vars = {
    static_ip = yandex_vpc_address.static_ip.external_ipv4_address[0].address
  }
}

# Создаём файл с подставленным IP
resource "local_file" "generated_ingress" {
  content  = data.template_file.ingress_yaml.rendered
  filename = "${path.module}/../tf/ingress.yaml"
}

resource "yandex_dns_zone" "main_zone" {
  name   = "akimovp-ru"
  zone   = "akimovp.ru."
  public = true
}

resource "yandex_dns_recordset" "a_root" {
  zone_id = yandex_dns_zone.main_zone.id
  name    = "akimovp.ru."
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.static_ip.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "a_mlflow" {
  zone_id = yandex_dns_zone.main_zone.id
  name    = "mlflow.akimovp.ru."
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.static_ip.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "txt_globalsign" {
  zone_id = yandex_dns_zone.main_zone.id
  name    = "_globalsign-domain-verification.akimovp.ru."
  type    = "TXT"
  ttl     = 300
  data    = ["_globalsign-domain-verification=YBiVtLgkjipH1ihBbNoGw0g17LMpyBPWrsomS6oCEN"]
}

resource "yandex_dns_recordset" "a_plg" {
  zone_id = yandex_dns_zone.main_zone.id
  name    = "plg.akimovp.ru."
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.static_ip.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "a_airflow" {
  zone_id = yandex_dns_zone.main_zone.id
  name    = "airflow.akimovp.ru."
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.static_ip.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "a_minio" {
  zone_id = yandex_dns_zone.main_zone.id
  name    = "minio.akimovp.ru."
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.static_ip.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "a_minio_console" {
  zone_id = yandex_dns_zone.main_zone.id
  name    = "minio-console.akimovp.ru."
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.static_ip.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "a_kafka" {
  zone_id = yandex_dns_zone.main_zone.id
  name    = "kafka.akimovp.ru."
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.static_ip.external_ipv4_address[0].address]
}

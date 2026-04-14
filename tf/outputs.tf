output "static_ip" {
  value = yandex_vpc_address.static_ip.external_ipv4_address[0].address
}

output "cluster_name" {
  value = yandex_kubernetes_cluster.akimovp_cluster.name
}

#output "bucket_name" {
#  value = yandex_storage_bucket.bucket.bucket
#}

#output "aws_access_key" {
#  value     = module.iam.access_key
#  sensitive = true
#}

#output "aws_secret_key" {
#  value     = module.iam.secret_key
#  sensitive = true
#}
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.109"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
  required_version = ">= 1.4.2"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = "ru-central1-a"
}



#provider "helm" {
#  kubernetes = {
#    config_path = var.kubeconfig_path
#  }
#}

#provider "kubernetes" {
#  config_path = var.kubeconfig_path
#}

data "yandex_client_config" "akimovp_cluster" {}

provider "helm" {
  kubernetes = {
    host                   = yandex_kubernetes_cluster.akimovp_cluster.master.0.external_v4_endpoint
    cluster_ca_certificate = yandex_kubernetes_cluster.akimovp_cluster.master.0.cluster_ca_certificate
    token                  = data.yandex_client_config.akimovp_cluster.iam_token
  }
}


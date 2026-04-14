resource "yandex_kubernetes_cluster" "akimovp_cluster" {
  name        = "akimovp-cluster"
  network_id  = yandex_vpc_network.k8s_network.id
  service_account_id = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id
  master {
    public_ip = true
    zonal {
      zone      = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.k8s_subnet.id
    }
  }

  depends_on = [
    yandex_iam_service_account.k8s_sa,
    yandex_resourcemanager_folder_iam_member.k8s_admin,
  ]
}

resource "yandex_kubernetes_node_group" "akimovp_nodes" {
  cluster_id = yandex_kubernetes_cluster.akimovp_cluster.id
  name       = "akimovp-node-group"

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = false
      subnet_ids = [yandex_vpc_subnet.k8s_subnet.id]
    }

    resources {
      memory = 12
      cores  = 6
    }

    boot_disk {
      type = "network-ssd"
      size = 32
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale { size = 1 }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }
  depends_on = [
    yandex_kubernetes_cluster.akimovp_cluster
  ]

}

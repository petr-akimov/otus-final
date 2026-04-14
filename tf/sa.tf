# ------------------------------------------------
# СЕРВИСНЫЙ АККАУНТ ДЛЯ КЛАСТЕРА KUBERNETES
# ------------------------------------------------

resource "yandex_iam_service_account" "k8s_sa" {
  name        = "k8s-cluster-sa"
  description = "Service account for Kubernetes cluster"
}

# Назначаем роль "editor" для этого SA в пределах текущей папки
resource "yandex_resourcemanager_folder_iam_member" "k8s_admin" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

# Создаём статический ключ для SA
resource "yandex_iam_service_account_static_access_key" "k8s_sa_key" {
  service_account_id = yandex_iam_service_account.k8s_sa.id
}

#resource "yandex_iam_service_account_key" "k8s_iam_key" {
#  service_account_id = yandex_iam_service_account.k8s_sa.id
#  description        = "IAM key for getting token via API"
#}

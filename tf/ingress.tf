resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "otus"
  create_namespace = true

  values = [<<EOF
controller:
  replicaCount: 1
  service:
    type: LoadBalancer
    loadBalancerIP: ${yandex_vpc_address.static_ip.external_ipv4_address[0].address}
    annotations:
      service.beta.kubernetes.io/yandex-load-balancer-type: "external"
      service.beta.kubernetes.io/yandex-load-balancer-ipv4-address: ${yandex_vpc_address.static_ip.external_ipv4_address[0].address}
  admissionWebhooks:
    enabled: false
EOF
  ]

  depends_on = [
    yandex_kubernetes_node_group.akimovp_nodes,
    yandex_vpc_address.static_ip
  ]
}

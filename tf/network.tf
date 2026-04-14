resource "yandex_vpc_network" "k8s_network" {
  name = "k8s-network"
}

resource "yandex_vpc_subnet" "k8s_subnet" {
  name           = "k8s-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.k8s_network.id
  v4_cidr_blocks = ["10.130.0.0/24"]
  route_table_id = yandex_vpc_route_table.nat_route_table.id 
}

resource "yandex_vpc_address" "static_ip" {
  name = "akimovp-static-ip"

  external_ipv4_address {
    zone_id = var.yc_zone
  }
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "akimovp-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat_route_table" {
  name       = "akimovp-nat-route-table"
  network_id = yandex_vpc_network.k8s_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    # Or, a gateway ID for the next hop.
    gateway_id = yandex_vpc_gateway.nat_gateway.id
  }

}

resource "azurerm_lb" "master_lb" {
  count               = "${var.number_of_masters > 1 ? 1 : 0}"
  name                = "master_lb"
  location            = "${azurerm_resource_group.swarm_cluster_rg.location}"
  resource_group_name = "${azurerm_resource_group.swarm_cluster_rg.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.main.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "master_lb_backend" {
  name                = "master_lb_backend"
  resource_group_name = "${azurerm_resource_group.swarm_cluster_rg.name}"
  loadbalancer_id     = "${azurerm_lb.master_lb.id}"
}

resource "azurerm_lb_nat_rule" "ssh_nat_rule" {
  count                          = "${var.number_of_masters}"
  resource_group_name            = "${azurerm_resource_group.swarm_cluster_rg.name}"
  loadbalancer_id                = "${azurerm_lb.master_lb.id}"
  name                           = "ssh_master${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = "${5000 + count.index}"
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_probe" "docker_port_probe" {
  resource_group_name = "${azurerm_resource_group.swarm_cluster_rg.name}"
  loadbalancer_id     = "${azurerm_lb.master_lb.id}"
  name                = "docker_port_probe"
  port                = "${var.docker_port}"
}

resource "azurerm_lb_rule" "docker_port_rule" {
  resource_group_name            = "${azurerm_resource_group.swarm_cluster_rg.name}"
  loadbalancer_id                = "${azurerm_lb.master_lb.id}"
  name                           = "docker_port"
  protocol                       = "Tcp"
  frontend_port                  = "${var.docker_port}"
  backend_port                   = "${var.docker_port}"
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = "${azurerm_lb_probe.docker_port_probe.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.master_lb_backend.id}"
}
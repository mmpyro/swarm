resource "azurerm_public_ip" "worker_ip" {
  name                = "worker_ip"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  allocation_method   = "Static"
}

resource "azurerm_lb" "worker_lb" {
  name                = "worker_lb"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.worker_ip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.worker_lb.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool_ssh" {
  resource_group_name            = "${var.resource_group_name}"
  name                           = "ssh"
  loadbalancer_id                = "${azurerm_lb.worker_lb.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50200
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_nat_pool" "lbnatpool_node_exporter" {
  resource_group_name            = "${var.resource_group_name}"
  name                           = "node_exporter"
  loadbalancer_id                = "${azurerm_lb.worker_lb.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 9100
  frontend_port_end              = 9200
  backend_port                   = 9100
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_nat_pool" "lbnatpool_cAdvisor" {
  resource_group_name            = "${var.resource_group_name}"
  name                           = "cAdvisor"
  loadbalancer_id                = "${azurerm_lb.worker_lb.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 8081
  frontend_port_end              = 8181
  backend_port                   = 8081
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_virtual_machine_scale_set" "worker_vmss" {
  name                = "worker"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  upgrade_policy_mode  = "Manual"

  sku {
    name     = "${var.worker_vm_size}"
    tier     = "${var.worker_vm_tier}"
    capacity = "${var.number_of_workers}"
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "${var.os_name}"
    sku       = "${var.os_version}"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "worker"
    admin_username       = "${var.vm_username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.vm_username}/.ssh/authorized_keys"
      key_data = "${file("${var.key_path}/${var.key_name}")}"
    }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = "${var.azurerm_subnet_id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
      load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.lbnatpool_ssh.*.id, count.index)}",
        "${element(azurerm_lb_nat_pool.lbnatpool_node_exporter.*.id, count.index)}", "${element(azurerm_lb_nat_pool.lbnatpool_cAdvisor.*.id, count.index)}"]
    }
  }

}
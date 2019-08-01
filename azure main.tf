resource "azurerm_resource_group" "rg" {
  name     = "LB_Resource"
  location = "japaneast"
}

resource "azurerm_public_ip" "rdpip" {
    name = "rdpip${count.index}"
    location = "japaneast"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    allocation_method = "Dynamic"
    count = 2
}
    //static 
    //private_ip_address = ""
resource "azurerm_public_ip" "pubip" {
    name = "myPublicIP"
    domain_name_label = "azuredns432"
    location = "japaneast"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    allocation_method = "Dynamic"
}

resource "azurerm_lb" "lb" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  name                = "lb"
  location = "japaneast"
  
  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.pubip.id}"
  }
}


resource "azurerm_lb_backend_address_pool" "bp" {
    resource_group_name = "${azurerm_resource_group.rg.name}"
    loadbalancer_id     = "${azurerm_lb.lb.id}"
    name                = "BackendPool1"
}

resource "azurerm_network_interface_backend_address_pool_association" "bpAS" {
  count = 2
  network_interface_id = "${element(azurerm_network_interface.nic.*.id, count.index)}"
  ip_configuration_name   = "ipconfig${count.index}" //Check!
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.bp.id}"
}


resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  name                           = "LBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bp.id}"
  idle_timeout_in_minutes        = 5
  probe_id                       = "${azurerm_lb_probe.lb_probe.id}"
  depends_on                     = ["azurerm_lb_probe.lb_probe"]
}


/*
resource "azurerm_lb_nat_rule" "tcp" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  name                           = "RDP-VM-${count.index}"
  protocol                       = "tcp"
  frontend_port                  = "5000${count.index + 1}"
  backend_port                   = 3389
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  count                          = 2
}
*/

resource "azurerm_virtual_network" "vnetwork" {
    name = "vnetwork"
    address_space = ["1.0.0.0/16"]
    location = "japaneast"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    
}

resource "azurerm_subnet" "mysubnet" {
    name = "MySubnet1"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    virtual_network_name = "${azurerm_virtual_network.vnetwork.name}"
    address_prefix = "1.0.1.0/24"

}
resource "azurerm_network_security_group" "secGroup" {
    name = "myNetworkSecurityGroup"
    location = "japaneast"
    resource_group_name ="${azurerm_resource_group.rg.name}"

    security_rule {
        name ="SSH"
        priority = "1001"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "HTTP"
        priority = "2001"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "80"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
    security_rule {
        name = "MSTSC"
        priority = "3001"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "3389"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }      
}

resource "azurerm_availability_set" "avset" {
  name                         = "avset"
  location = "japaneast"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_network_interface" "nic" {
  name                = "nic${count.index}"
  location            = "japaneast"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  network_security_group_id = "${azurerm_network_security_group.secGroup.id}"  
  count               = 2

  ip_configuration {
    name                                    = "ipconfig${count.index}"
    subnet_id                               = "${azurerm_subnet.mysubnet.id}"
    private_ip_address_allocation           = "Dynamic"    
    //public_ip_address_id = "${azurerm_public_ip.rdpip.*.id[count.index]}"
    //public_ip_address_id                    = "${element(azurerm_public_ip.rdpip.*.id, count.index)}"
    public_ip_address_id = "${length(azurerm_public_ip.rdpip.*.id) > 0 ? element(concat(azurerm_public_ip.rdpip.*.id, list("")), count.index) : ""}"

  // "${azurerm_public_ip.rdpip.id}"
   // "rdpip${count.index}"
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "vm${count.index}"
  location              = "japaneast"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  vm_size = "Standard_D1_v2"
  count = 2


  storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2016-Datacenter"
        version   = "latest"
  }

  storage_os_disk {
        name = "osdisk${count.index}"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
  }

  os_profile {
        computer_name = "myvm"
        admin_username = "azureuser"
        admin_password= "Passw0rd"
  }

  os_profile_windows_config {
        provision_vm_agent        = true
        enable_automatic_upgrades = true
  }
}



resource "azurerm_resource_group" "rg" {
  name     = "user15-rg"
  location = "japaneast"
}

variable "application_port" {
   description = "The port that you want to expose to the external load balancer"
   default     = 80
}
variable "admin_user" {
   description = "User name to use as the admin account on the VMs that will be part of the VM Scale Set"
   default     = "azureuser"
}
variable "admin_password" {
   description = "password"
   default     = "Passw0rd"

}
variable "location" {
 description = "location"
 default     = "japaneast"

}

variable "tags" {
 description = "A map of the tags to use for the resources that are deployed"
 type        = "map"
 default = {
   environment = "codelab"
 }
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
}

resource "azurerm_network_security_group" "secGroup2" {
    name = "myNetworkSecurityGroup2"
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
        name = "db"
        priority = "3001"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "3306"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }    
}
resource "azurerm_virtual_network" "vnetwork" {
    name = "vnetwork"
    address_space = ["15.0.0.0/16"]
    location = "japaneast"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    
}
resource "azurerm_subnet" "mysubnet" {
    name = "MySubnet1"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    virtual_network_name = "${azurerm_virtual_network.vnetwork.name}"
    network_security_group_id = "${azurerm_network_security_group.secGroup.id}"
    address_prefix = "15.0.1.0/24"
}
resource "azurerm_subnet" "mysubnet2" {
    name = "MySubnet2"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    virtual_network_name = "${azurerm_virtual_network.vnetwork.name}"
    network_security_group_id = "${azurerm_network_security_group.secGroup2.id}"
    address_prefix = "15.0.2.0/24"
}

output "vmss_public_ip" {
     value = "${azurerm_public_ip.vmss.fqdn}"
 }

resource "random_string" "fqdn" {
 length  = 9
 special = false
 upper   = false
 number  = true
}

resource "azurerm_public_ip" "vmss" {
 name                         = "vmss-public-ip"
 location                     = "japaneast"
 resource_group_name          = "${azurerm_resource_group.rg.name}"
 allocation_method            = "Static"
 domain_name_label            = "${random_string.fqdn.result}"
}

resource "azurerm_lb" "vmss" {
 name                = "vmss-lb"
 location                     = "japaneast"
 resource_group_name          = "${azurerm_resource_group.rg.name}"

 frontend_ip_configuration {
   name                 = "PublicIPAddress"
   public_ip_address_id = "${azurerm_public_ip.vmss.id}"
 }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
 resource_group_name = "${azurerm_resource_group.rg.name}"
 loadbalancer_id     = "${azurerm_lb.vmss.id}"
 name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
 resource_group_name = "${azurerm_resource_group.rg.name}"
 loadbalancer_id     = "${azurerm_lb.vmss.id}"
 name                = "ssh-running-probe"
 port                = "${var.application_port}"
}

resource "azurerm_lb_rule" "lbnatrule" {
   resource_group_name            = "${azurerm_resource_group.rg.name}"
   loadbalancer_id                = "${azurerm_lb.vmss.id}"
   name                           = "http"
   protocol                       = "Tcp"
   frontend_port                  = "${var.application_port}"
   backend_port                   = "${var.application_port}"
   backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bpepool.id}"
   frontend_ip_configuration_name = "PublicIPAddress"
   probe_id                       = "${azurerm_lb_probe.vmss.id}"
}

resource "azurerm_virtual_machine_scale_set" "vmssvset" {
    name = "vmssscalesetuser15"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    upgrade_policy_mode = "Manual"

    sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 3
    }

    storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
    }

    storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    }

    storage_profile_data_disk {
    lun            =   0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
    }

    os_profile {
    computer_name_prefix = "vmlab"
    admin_username       = "${var.admin_user}"
    admin_password       = "${var.admin_password}"
    custom_data          = "${file("web.conf")}"
    }

    os_profile_linux_config {
    disable_password_authentication = false
    /*
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3Nz{snip}hwhqT9h"
        }
        */   
    }

    network_profile {
    name    = "terraformnetworkprofile"
    primary = true

        ip_configuration {
            name                                   = "IPConfiguration"
            subnet_id                              = "${azurerm_subnet.mysubnet.id}"
            load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
            primary = true
        }
    }
 tags = "${var.tags}"
}

resource "azurerm_public_ip" "jumpbox" {
 name                         = "jumpbox-public-ip"
 location                     = "${var.location}"
 resource_group_name          = "${azurerm_resource_group.rg.name}"
 allocation_method            = "Static"
 domain_name_label            = "${random_string.fqdn.result}"
 tags                         = "${var.tags}"
}

resource "azurerm_network_interface" "jumpboxnic" {
 name                = "jumpbox-nic"
 location            = "${var.location}"
 resource_group_name = "${azurerm_resource_group.rg.name}"

 ip_configuration {
   name                          = "IPConfiguration"
   subnet_id                     = "${azurerm_subnet.mysubnet.id}"
   private_ip_address_allocation = "dynamic"
   public_ip_address_id          = "${azurerm_public_ip.jumpbox.id}"
 }
 tags = "${var.tags}"
}

resource "azurerm_virtual_machine" "jumpboxvm" {
 name                  = "jumpbox"
 location              = "${var.location}"
 resource_group_name   = "${azurerm_resource_group.rg.name}"
 network_interface_ids = ["${azurerm_network_interface.jumpboxnic.id}"]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "jumpbox-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "jumpbox"
   admin_username = "${var.admin_user}"
   admin_password = "${var.admin_password}"
 }

 os_profile_linux_config {
   disable_password_authentication = false
   /*
    ssh_keys {
        path     = "/home/azureuser/.ssh/authorized_keys"
        key_data = "ssh-rsa AAAAB3Nz{snip}hwhqT9h"
    }
    */      
 }

 tags = "${var.tags}"
}

output "jumpbox_public_ip" {
   value = "${azurerm_public_ip.jumpbox.fqdn}"
}

resource "azurerm_public_ip" "dbip" {
 name                         = "DB-public-ip"
 location                     = "${var.location}"
 resource_group_name          = "${azurerm_resource_group.rg.name}"
 allocation_method = "Static"
 domain_name_label            = "${random_string.fqdn.result}-db-ssh"
 tags                         = "${var.tags}"
}

resource "azurerm_network_interface" "dbnic" {
 name                = "DB-nic"
 location            = "${var.location}"
 resource_group_name = "${azurerm_resource_group.rg.name}"

 ip_configuration {
   name                          = "IPConfiguration"
   subnet_id                     = "${azurerm_subnet.mysubnet.id}"
   private_ip_address_allocation = "dynamic"
   public_ip_address_id          = "${azurerm_public_ip.dbip.id}"
 }
    tags = "${var.tags}"
}

resource "azurerm_virtual_machine" "dbserver" {
 name                  = "Dbserver"
 location              = "${var.location}"
 resource_group_name   = "${azurerm_resource_group.rg.name}"
 network_interface_ids = ["${azurerm_network_interface.dbnic.id}"]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "dbserver-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "dbserver"
   admin_username = "${var.admin_user}"
   admin_password = "${var.admin_password}"
 }

 os_profile_linux_config {
   disable_password_authentication = false
   /*
    ssh_keys {
        path     = "/home/azureuser/.ssh/authorized_keys"
        key_data = "ssh-rsa AAAAB3Nz{snip}hwhqT9h"
    }
    */      
 }

 tags = "${var.tags}"
}

output "DB_public_ip" {
   value = "${azurerm_public_ip.dbip.fqdn}"
}


/*

resource "azurerm_mysql_server" "dbserver" {
  name                = "mysql-server"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  sku {
    name     = "B_Gen5_2"
    capacity = 1
    tier     = "Basic"
    family   = "Gen5"
  }

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 7
    geo_redundant_backup  = "Disabled"
  }

  administrator_login          = "mysql"
  administrator_login_password = "Passw0rd"
  version                      = "5.7"
  ssl_enforcement              = "Enabled"
}

resource "azurerm_mysql_database" "test" {
  name                = "exampledb"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  server_name         = "${azurerm_mysql_server.dbserver.name}"
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}
*/

resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }
  byte_length = 8
}

resource "azurerm_traffic_manager_profile" "interprovider" {
  name                   = "interprovider-trafficmanager"
  resource_group_name    = "${azurerm_resource_group.rg.name}"
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${random_id.server.hex}"
    ttl           = 30
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}
/*
resource "azurerm_traffic_manager_endpoint" "azure-point" {
  name                = "azure-point"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  target_resource_id  = "${azurerm_lb.lb.id}"
  type                = "azureEndpoints"
  weight              = 1
}

resource "azurerm_traffic_manager_endpoint" "AWS-Point" {
  name                = "AWS-Point"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  target              = "${aws_eip.awspubeip.id}"
  type                = "externalEndpoints"
  weight              = 2
}


resource "azurerm_traffic_manager_endpoint" "azure" {
  name                = "${random_id.server.hex}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  target              = "terraform.io"
  type                = "externalEndpoints"
  weight              = 100
}
*/
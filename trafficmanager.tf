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

resource "azurerm_traffic_manager_endpoint" "azureLB" {
  name                = "first"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  //target              = "user15skcncazure2.japaneast.cloudapp.azure.com"
  target_resource_id  = "${azurerm_public_ip.vmss.id}"
  type                = "azureEndpoints"
  weight              = 1
}

resource "azurerm_traffic_manager_endpoint" "awsLB" {
  name                = "second"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  target              = "54.178.159.222"
  type                = "externalEndpoints"
  weight              = 2
}

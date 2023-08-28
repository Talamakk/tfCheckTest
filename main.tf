terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.71.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  # Configuration options
  features {}
}

provider "random" {

}

resource "random_string" "random1" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  name     = join("-", ["rg", var.region, var.env])
  location = var.region
}


resource "azurerm_container_group" "container" {
  name                = join("-", ["acg", random_string.random1.result, var.region, var.env])
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Public"
  os_type             = "Linux"
  restart_policy      = "Always"
  dns_name_label      = "${random_string.random1.result}-container"

  container {
    name   = join("-", ["aci", random_string.random1.result, var.region, var.env])
    image  = var.image
    cpu    = 1
    memory = 2

    ports {
      port     = 80
      protocol = "TCP"
    }
  }
}

output "app-fqdn" {
  value       = azurerm_container_group.container.fqdn
  description = "The fqdn of the app instance."
}


check "health_check" {

  data "http" "container_check" {
    depends_on = [
      azurerm_container_group.container
    ]
    url                = "http://${azurerm_container_group.container.fqdn}"
    request_timeout_ms = 10000
  }

  assert {
    condition     = data.http.container_check.status_code == 200
    error_message = "returned an unhealthy status code"
  }
}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.74.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.7.0"
    }
    http = {
      source = "hashicorp/http"
      version = "2.1.0"
    }
    tls = {
      version = "3.1.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

provider "kubernetes" {
  host = "https://${module.vdc.kubernetes_server}"

  cluster_ca_certificate = base64decode(
    module.vdc.kube_config.cluster_ca_certificate
  )
  client_certificate = base64decode(
    module.vdc.kube_config.client_certificate
  )
  client_key = base64decode(
    module.vdc.kube_config.client_key
  )
}

locals {
  acr_name = var.acr_name == "" ? var.az_resource_group_name : var.acr_name
}

data "azurerm_subscription" "primary" {}
data "azurerm_resource_group" "rg" {
  name = var.az_resource_group_name
}

resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = var.acr_sku
}

module "vdc" {
  source = "./modules/vdc"

  resource_group        = data.azurerm_resource_group.rg
  container_registry_id = azurerm_container_registry.acr.id
  k8s_machine_type      = var.k8s_machine_type
}

module "db" {
  source = "./modules/db"

  resource_group = data.azurerm_resource_group.rg
  subnet_id      = module.vdc.db_subnet_id
}

module "auth" {
  source = "./modules/auth"

  resource_group_name = data.azurerm_resource_group.rg.name
  domain              = var.domain
}

module "batch" {
  source = "./modules/batch"

  resource_group        = data.azurerm_resource_group.rg
  container_registry_id = azurerm_container_registry.acr.id
}

module "global_config" {
  source = "../k8s/global_config"

  cloud                  = "azure"
  domain                 = var.domain
  docker_prefix          = azurerm_container_registry.acr.login_server
  internal_gateway_ip    = module.vdc.internal_gateway_ip
  gateway_ip             = module.vdc.gateway_ip
  kubernetes_server      = module.vdc.kubernetes_server
  batch_logs_storage_uri = module.batch.batch_logs_storage_uri
  test_storage_uri       = module.batch.test_storage_uri
  organization_domain    = var.organization_domain

  extra_fields = {
    azure_subscription_id = data.azurerm_subscription.primary.subscription_id
    azure_resource_group  = data.azurerm_resource_group.rg.name
    azure_location        = data.azurerm_resource_group.rg.location
  }
}

module "ci" {
  source = "./modules/ci"
  count = var.ci_config != null ? 1 : 0

  resource_group         = data.azurerm_resource_group.rg
  ci_principal_id        = module.batch.ci_principal_id
  container_registry_id  = azurerm_container_registry.acr.id

  test_storage_container_resource_id = module.batch.test_storage_container.resource_manager_id

  deploy_steps                            = var.ci_config.deploy_steps
  watched_branches                        = var.ci_config.watched_branches
  github_context                          = var.ci_config.github_context
  ci_and_deploy_github_oauth_token        = var.ci_config.ci_and_deploy_github_oauth_token
  ci_test_repo_creator_github_oauth_token = var.ci_config.ci_test_repo_creator_github_oauth_token
}

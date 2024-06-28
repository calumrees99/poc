terraform {
  required_providers {
    barracudawaf = {
      source = "barracudanetworks/barracudawaf"
      version = "1.0.10"
    }
  }
}
variable "publicIpAddress" {
  type = string
}

variable "adminPassword" {
  type = string
  sensitive = true
}

variable "privateIpAddress" {
  type = string
}

variable "customHostname" {
  type = string
}

variable "backendServerHostname" {
  type = string
}

provider "barracudawaf" {
    address  = var.publicIpAddress
    username = "admin"
    port     = "8443"
    password = var.adminPassword
}

resource "barracudawaf_services" "demo_app_1" {
    name            = "DemoApp1"
    ip_address      = var.privateIpAddress
    port            = "80"
    type            = "HTTP"
    vsite           = "default"
    address_version = "IPv4"
    status          = "On"
    group           = "default"
    comments        = "Demo Service with Terraform"

    basic_security {
      mode = "Passive"
    }
}

resource "barracudawaf_content_rules" "demo_rule_group_1" {
    name                = "DemoRuleGroup1"
    url_match           = "/*"
    host_match          = var.customHostname
    web_firewall_policy = "default"
    mode                = "Passive"
    parent              = [ barracudawaf_services.demo_app_1.name ]
    }

resource "barracudawaf_servers" "demo_server_1" {
    name            = "DemoServer1"
    identifier      = "Hostname"
    hostname        = var.backendServerHostname
    address_version = "IPv4"
    status          = "In Service"
    port            = "80"
    comments        = "Creating the Demo Server"
    parent          = [ barracudawaf_services.demo_app_1.name ]

}
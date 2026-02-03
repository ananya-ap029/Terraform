variable "project" {
  type    = string
  default = "test"
}

variable "loc" {
  type    = string
  default = ""
}

variable "dr_loc" {  
  type    = string
  default = ""
}

variable "env" {
  type    = string
  default = "dev"
}

variable "region_short" {
  type    = string #
  default = ""
}

variable "ip_address_list" {
  type    = list(string)
  default = ["",""]
}

variable "dr_region_short" {
  type    = string 
  default = ""
}

locals {
default_tags = {
  application_name = "${var.project}-${var.env}-${var.region_short}-${var.deployment-number}"
  environment = "${var.env}"
  owner = ""
  cost_centre = ""
  criticality = "${var.criticality}"
  business_unit = ""
  }
}

variable "ip_address_list_for_storage_account" {
  type    = list(string)
  default = ["",""]
}

variable "agent_ipaddress" {
  type = list(string)
  default = []
}

variable "appgateway_min_capacity" {
  type = number
  default = 1
}

variable "appgateway_max_capacity" {
  type = number
  default = 2
}


variable "app_gateway_zones" {
  type = list(number)
  default = ["1", "2", "3"]
}

variable "kv_sku_names" {
  type = string
  default = "standard"
}

variable "min_number_of_webapp_instances" {
  type = number
  default = 1
}

variable "max_number_of_webapp_instances" {
  type = number
  default = 2
}

variable "default_number_of_webapp_instances" {
  type = number
  default = 1
}

variable "storage_acc_replication_type" {
  type = string
  default = "LRS"
}

variable "redis_replicas" {
  type = number
  default = 0
}

variable "webapp_sku" {
  type = string 
  default = "B1"
}

variable "location" {
  description = "Location to deploy resources"
  type        = string
  default     = "germanywestcentral"
}

variable "username" {
  description = "Username for Virtual Machines"
  type        = string
  default     = "username"
}

variable "password" {
  description = "Password must meet Azure complexity requirements"
  type        = string
  default     = "Thi5i$aPssWord4Az0Re"
}

variable "vmsize" {
  description = "Size of the VMs"
  default     = "Standard_B4ms"
}

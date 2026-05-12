variable "do_token" {
  description = "DigitalOcean API token. Pass with TF_VAR_do_token or a secure tfvars file."
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of an existing DigitalOcean SSH key."
  type        = string
}

variable "droplet_name" {
  description = "Droplet name."
  type        = string
  default     = "todo-api-01"
}

variable "region" {
  description = "DigitalOcean region slug."
  type        = string
  default     = "sgp1"
}

variable "size" {
  description = "Droplet size slug."
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "image" {
  description = "Droplet base image."
  type        = string
  default     = "ubuntu-24-04-x64"
}

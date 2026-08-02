###############################################################################
# Variables
###############################################################################

variable "aws_region" {
  description = "AWS region to deploy in (must support g6e instances)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-2", "eu-central-1", "eu-north-1", "ap-northeast-1", "ap-northeast-2"], var.aws_region)
    error_message = "Region must support g6e instances."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "isaac-lab"
}

# --------------------------------------------------------------------------- #
# Isaac Lab / Sim versions
# --------------------------------------------------------------------------- #

variable "isaac_lab_version" {
  description = "Isaac Lab release tag (e.g. v2.1.0)"
  type        = string
  default     = "v2.1.0"
}

variable "isaac_sim_version" {
  description = "Isaac Sim container tag on NGC"
  type        = string
  default     = "4.5.0"
}

variable "ngc_api_key" {
  description = "NVIDIA NGC API key for pulling Isaac Sim container"
  type        = string
  sensitive   = true
}

# --------------------------------------------------------------------------- #
# SSH
# --------------------------------------------------------------------------- #

variable "existing_key_name" {
  description = "Name of an existing AWS key pair to use. If set, ssh_public_key is ignored."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key content. Leave empty to auto-generate an ED25519 key pair. Ignored if existing_key_name is set."
  type        = string
  default     = ""
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --------------------------------------------------------------------------- #
# Storage
# --------------------------------------------------------------------------- #

variable "root_volume_size_gb" {
  description = "Root EBS volume size (OS + Docker images, recommend >= 200 GB)"
  type        = number
  default     = 300
}

variable "data_volume_size_gb" {
  description = "Data EBS volume size for datasets / checkpoints"
  type        = number
  default     = 500
}

variable "checkpoint_bucket" {
  description = "S3 bucket name prefix for syncing training checkpoints (account ID is appended for global uniqueness; bucket is created by Terraform)"
  type        = string
  default     = "isaac-lab-checkpoints"

  validation {
    # 계정 ID 접미사(13자)를 붙여도 S3 이름 제한(63자)을 넘지 않아야 함
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,48}$", var.checkpoint_bucket))
    error_message = "checkpoint_bucket must be 2-49 chars of lowercase letters, digits, dots, or hyphens, starting with a letter or digit."
  }
}

# --------------------------------------------------------------------------- #
# Cost management
# --------------------------------------------------------------------------- #

variable "enable_idle_stop" {
  description = "Enable CloudWatch alarm to auto-stop instance when GPU is idle"
  type        = bool
  default     = true
}

variable "spot_max_price" {
  description = "Max hourly price for spot instance (only used if spot block is uncommented)"
  type        = string
  default     = "2.50"
}

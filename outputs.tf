###############################################################################
# Outputs
###############################################################################

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.isaac.id
}

output "public_ip" {
  description = "Public IP of the Isaac Lab instance"
  value       = aws_eip.isaac.public_ip
}

output "public_dns" {
  description = "Public DNS of the Isaac Lab instance"
  value       = aws_eip.isaac.public_dns
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = var.existing_key_name != "" ? "ssh -i ${var.existing_key_name}.pem ubuntu@${aws_eip.isaac.public_ip}" : "ssh -i isaac-lab-key ubuntu@${aws_eip.isaac.public_ip}"
}

output "ssh_private_key" {
  description = "Auto-generated SSH private key (only if no existing key and ssh_public_key was empty)"
  value       = var.existing_key_name == "" && var.ssh_public_key == "" ? tls_private_key.ssh[0].private_key_openssh : "Using existing or user-provided key"
  sensitive   = true
}

output "checkpoint_bucket" {
  description = "S3 bucket for training checkpoint sync (prefix + account ID)"
  value       = aws_s3_bucket.checkpoints.bucket
}

output "ami_id" {
  description = "AMI used for the instance"
  value       = data.aws_ami.dl_base.id
}

output "ami_name" {
  description = "AMI name"
  value       = data.aws_ami.dl_base.name
}

output "instance_spec" {
  description = "Instance specification summary"
  value = {
    type    = "g6e.4xlarge"
    gpu     = "1× NVIDIA L40S (48 GB)"
    vcpu    = 16
    memory  = "128 GiB"
    storage = "600 GB NVMe instance store"
    region  = var.aws_region
    cost_hr = "~$3.00/hr (on-demand)"
  }
}

output "quick_start" {
  description = "Quick start commands after SSH"
  value       = <<-EOT

    # 1. SSH into the instance
    ssh -i isaac-lab-key ubuntu@${aws_eip.isaac.public_ip}

    # 2. Check GPU status
    nvidia-smi

    # 3. Run a headless training
    isaac-lab-run source/standalone/workflows/rsl_rl/train.py \
      --task Isaac-Velocity-Rough-Anymal-C-v0 --headless

    # 4. Interactive Isaac Sim shell
    isaac-sim-shell

    # 5. Sync checkpoints to S3
    sync-checkpoints

  EOT
}

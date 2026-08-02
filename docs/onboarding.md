# Developer Onboarding

## Quick Start

### 1. Prerequisites
- [ ] Terraform v1.5+ installed
- [ ] AWS CLI configured with appropriate credentials
- [ ] SSH key pair (.pem) for EC2 access
- [ ] NGC API key (from NVIDIA NGC portal)
- [ ] Node.js 16+ (for workshop docs)

### 2. Setup

```bash
# Clone repository
git clone <repo-url> && cd pai-sim-isaaclab

# Run setup script
bash scripts/setup.sh

# Copy and edit terraform variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your NGC API key, key pair name, etc.

# Initialize Terraform
terraform init
```

### 3. Verify

```bash
terraform validate
terraform plan
```

## Project Overview
- Read `CLAUDE.md` for project context and conventions
- Read `docs/architecture.md` for system design
- Review `docs/decisions/` for architectural decisions

## Development Workflow
- Branch naming: `feat/`, `fix/`, `docs/`, `refactor/`
- Commit convention: Conventional Commits
- Infrastructure changes: always `terraform plan` before `terraform apply`

## Key Concepts
- **Isaac Lab**: NVIDIA's robot simulation framework based on Isaac Sim
- **ANYmal-C**: Quadruped robot by ANYbotics, used as the RL training target
- **PPO**: Proximal Policy Optimization, the RL algorithm used for training
- **Sim-to-Real**: Transferring policies trained in simulation to physical robots

## Troubleshooting

### Terraform init fails
```bash
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Workshop build fails
```bash
cd workshop
rm -rf node_modules _book
npm install
npx honkit build
```

## Resources
- [NVIDIA Isaac Lab Documentation](https://isaac-sim.github.io/IsaacLab/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [HonKit Documentation](https://honkit.netlify.app/)

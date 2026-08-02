# pai-sim-isaaclab

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-623CE4.svg)](https://www.terraform.io/)
[![Isaac Lab](https://img.shields.io/badge/Isaac%20Lab-v2.1.0-76B900.svg)](https://isaac-sim.github.io/IsaacLab/)
[![Isaac Sim](https://img.shields.io/badge/Isaac%20Sim-4.5.0-76B900.svg)](https://developer.nvidia.com/isaac-sim)
<a href="#english"><img src="https://img.shields.io/badge/lang-English-blue.svg" alt="English"></a>
<a href="#한국어"><img src="https://img.shields.io/badge/lang-한국어-red.svg" alt="Korean"></a>

**End-to-end pipeline for training quadruped robot locomotion with reinforcement learning on AWS GPU instances using NVIDIA Isaac Lab**

**Terraform으로 AWS GPU 인프라를 구축하고 NVIDIA Isaac Lab에서 4족 보행 로봇의 강화학습을 실행하는 엔드투엔드 파이프라인**

---

# English

> **⚠️ Workshop / educational use only** — This project is designed for short-lived, hands-on workshop environments and is **not hardened for production**. Before any long-lived or production deployment, review the security posture: restrict `allowed_ssh_cidrs`, tighten IAM scope, enable VPC flow logs, and manage secrets outside `terraform.tfvars`.

## Overview

pai-sim-isaaclab is an end-to-end pipeline that provisions AWS GPU infrastructure with Terraform and trains an ANYmal-C quadruped robot to walk over rough terrain using PPO reinforcement learning in NVIDIA Isaac Lab. The entire process — from infrastructure deployment to trained policy export — completes in under 2 hours for approximately $12.

A step-by-step Korean workshop (7 Labs + 3 Appendices) guides users through every stage, from Terraform deployment to Sim-to-Real policy export.

<p align="center">
  <img src=".gitbook/assets/play30_frame_15s (1).png" alt="ANYmal-C walking on rough terrain" width="720">
  <br>
  <em>Trained ANYmal-C walking stably on rough block terrain</em>
</p>

## Features

- **One-command GPU infrastructure** — Terraform provisions VPC, g6e.4xlarge EC2 (NVIDIA L40S), KMS-encrypted EBS volumes, an Elastic IP, IAM roles, and CloudWatch alarms in a single `terraform apply`.
- **Automated environment bootstrap** — `user_data.sh` handles NGC login, Isaac Sim Docker pull, Isaac Lab source build, and wrapper script generation without manual intervention.
- **PPO reinforcement learning** — Trains ANYmal-C locomotion with 4,096 parallel environments, reaching +16.29 mean reward in 75 minutes / 1,500 iterations.
- **Sim-to-Real policy export** — Exports trained policies as TorchScript JIT (`.pt`) and ONNX (`.onnx`) for deployment on physical robots via TensorRT/Jetson.
- **Cost-optimized operation** — CloudWatch GPU idle detection auto-stops instances after 30 minutes; S3 checkpoint sync protects against Spot interruptions. The Elastic IP keeps the SSH endpoint stable across stop/start cycles.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [NVIDIA NGC](https://ngc.nvidia.com/) API Key
- g6e instance service quota approved ([Service Quotas](https://console.aws.amazon.com/servicequotas/))
- SSH key pair for EC2 access

## Installation

```bash
# Clone the repository
git clone https://github.com/comeddy/pai-sim-isaaclab.git
cd pai-sim-isaaclab

# Copy and configure Terraform variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set NGC API key, SSH key, region, etc.

# Initialize and deploy infrastructure (~3 minutes)
terraform init
terraform plan
terraform apply
```

## Usage

### SSH into the instance and verify boot

```bash
ssh -i your-key.pem ubuntu@$(terraform output -raw public_ip)

# Monitor bootstrap progress (15-25 minutes)
tail -f /var/log/isaac-lab-setup.log
# Wait for "Isaac Lab setup COMPLETE" message
```

### Install core isaaclab package (required one-time step)

```bash
docker run --name setup --gpus all \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  --entrypoint bash isaac-lab-base:latest -c '
    /workspace/isaaclab/_isaac_sim/python.sh -m pip install \
      --no-build-isolation -e /workspace/isaaclab/source/isaaclab
    cd /workspace/isaaclab && ./isaaclab.sh -i rsl_rl
  '
docker commit setup isaac-lab-ready:latest
docker rm setup
```

### Run PPO training

```bash
docker run --rm --gpus all --network=host \
  --entrypoint /workspace/isaaclab/isaaclab.sh \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  -v "/scratch/isaac-sim-cache/kit:/isaac-sim/kit/cache:rw" \
  -v "/data/checkpoints:/workspace/isaaclab/logs:rw" \
  isaac-lab-ready:latest \
  -p scripts/reinforcement_learning/rsl_rl/train.py \
    --task Isaac-Velocity-Rough-Anymal-C-v0 \
    --headless
# Training takes ~75 minutes for 1,500 iterations
```

### Run Play mode and export policy

```bash
docker run --rm --gpus all --network=host \
  --entrypoint /workspace/isaaclab/isaaclab.sh \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  -v "/scratch/isaac-sim-cache/kit:/isaac-sim/kit/cache:rw" \
  -v "/data/checkpoints:/workspace/isaaclab/logs:rw" \
  isaac-lab-ready:latest \
  -p scripts/reinforcement_learning/rsl_rl/play.py \
    --task Isaac-Velocity-Rough-Anymal-C-v0 \
    --headless --video --video_length 1500 --num_envs 16 \
    --load_run <TIMESTAMP_DIR>
# Outputs: rl-video-step-0.mp4, exported/policy.pt, exported/policy.onnx
```

### Clean up all resources

```bash
terraform destroy
```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region (must support g6e instances) | `us-east-1` |
| `project_name` | Project name for resource naming and tagging | `isaac-lab` |
| `isaac_lab_version` | Isaac Lab release tag | `v2.1.0` |
| `isaac_sim_version` | Isaac Sim container tag on NGC | `4.5.0` |
| `ngc_api_key` | NVIDIA NGC API key (sensitive) | — |
| `root_volume_size_gb` | Root EBS volume size (OS + Docker images) | `300` |
| `data_volume_size_gb` | Data EBS volume size (datasets + checkpoints) | `500` |
| `checkpoint_bucket` | S3 bucket name prefix for checkpoint sync (account ID appended; bucket created by Terraform) | `isaac-lab-checkpoints` |
| `enable_idle_stop` | Auto-stop instance when GPU idle for 30 min | `true` |
| `allowed_ssh_cidrs` | CIDR blocks allowed to SSH | `["0.0.0.0/0"]` |

> **Security note**: `ngc_api_key` is rendered into EC2 user data and stored in Terraform state in plain text. For anything beyond a short-lived workshop, store the key in **AWS Secrets Manager** (or SSM Parameter Store) and fetch it at boot through the instance role instead of passing it via `terraform.tfvars`. Also set `allowed_ssh_cidrs` to your own IP (`x.x.x.x/32`) rather than the open default.

## Project Structure

```
pai-sim-isaaclab/
├── main.tf                       # Terraform: VPC, EC2, EBS, IAM, CloudWatch
├── variables.tf                  # Input variable definitions
├── outputs.tf                    # Outputs (IP, SSH command)
├── terraform.tfvars.example      # Variable template (copy to terraform.tfvars)
├── user_data.sh                  # EC2 bootstrap (Docker, Isaac Lab auto-install)
├── docs/                         # Architecture docs, ADRs, runbooks
│   ├── architecture.md           # System architecture (bilingual)
│   ├── decisions/                # Architecture Decision Records
│   ├── runbooks/                 # Operational runbooks
│   └── onboarding.md            # Developer onboarding guide
├── workshop/                     # HonKit workshop (7 Labs + 3 Appendices)
│   ├── SUMMARY.md               # Table of contents
│   ├── book.json                # HonKit configuration
│   └── chapters/                # Markdown content per lab
├── deck/                         # Workshop overview deck (standalone HTML slides)
├── models/                       # Trained policy models
│   ├── policy_jit.pt            # TorchScript JIT (C++ inference)
│   └── policy.onnx              # ONNX (TensorRT/Jetson deployment)
├── videos/                       # Play mode recordings
├── images/                       # Dashboard screenshots, frame captures
├── isaac_lab_dashboard.html      # Chart.js training metrics dashboard
├── scripts/                      # Setup and deployment scripts
├── tests/                        # Harness engineering tests
└── .claude/                      # Claude Code settings, hooks, skills
```

## Testing

```bash
# Run the full harness test suite
bash tests/run-all.sh

# Run only hook tests
bash tests/run-all.sh hooks

# Run only structure tests
bash tests/run-all.sh structure

# Validate Terraform configuration
terraform validate
terraform fmt -check
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Commit changes using Conventional Commits (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

Commit message examples:

```
feat: add Spot instance support for cost optimization
fix: resolve EBS mount failure on Nitro instances
docs: update training parameters in Lab 4
```

## License

This project's Terraform code and workshop documentation are released under the [MIT License](LICENSE). Isaac Sim / Isaac Lab are subject to the [NVIDIA EULA](https://docs.omniverse.nvidia.com/isaacsim/latest/common/NVIDIA_Omniverse_License_Agreement.html).

## Contact

- Maintainer: [@comeddy](https://github.com/comeddy)
- Issues: [GitHub Issues](https://github.com/comeddy/pai-sim-isaaclab/issues)

---

# 한국어

> **⚠️ 워크샵/교육용 환경** — 이 프로젝트는 단기 실습용으로 설계되었으며 **프로덕션 수준으로 강화되어 있지 않습니다**. 장기 운영이나 프로덕션 배포 전에는 보안 구성을 재검토하세요: `allowed_ssh_cidrs` 제한, IAM 권한 최소화, VPC Flow Logs 활성화, 시크릿을 `terraform.tfvars` 밖에서 관리.

## 개요

pai-sim-isaaclab은 Terraform으로 AWS GPU 인프라를 프로비저닝하고, NVIDIA Isaac Lab에서 PPO 강화학습을 사용하여 ANYmal-C 4족 보행 로봇이 거친 지형 위를 걷도록 훈련하는 엔드투엔드 파이프라인입니다. 인프라 배포부터 학습된 정책 추출까지 전체 과정이 약 2시간, 약 $12(₩16,000)에 완료됩니다.

단계별 한국어 워크샵(7개 Lab + 3개 부록)이 Terraform 배포부터 Sim-to-Real 정책 추출까지 모든 과정을 안내합니다.

<p align="center">
  <img src=".gitbook/assets/play30_frame_15s (1).png" alt="ANYmal-C 거친 지형 보행" width="720">
  <br>
  <em>학습된 ANYmal-C가 울퉁불퉁한 블록 지형 위를 안정적으로 보행하는 모습</em>
</p>

## 주요 기능

- **원커맨드 GPU 인프라** — Terraform이 VPC, g6e.4xlarge EC2(NVIDIA L40S), KMS CMK로 암호화된 EBS 볼륨, Elastic IP, IAM 역할, CloudWatch 알람을 단일 `terraform apply`로 프로비저닝합니다.
- **자동 환경 부트스트랩** — `user_data.sh`가 NGC 로그인, Isaac Sim Docker pull, Isaac Lab 소스 빌드, 래퍼 스크립트 생성을 수동 개입 없이 처리합니다.
- **PPO 강화학습** — 4,096개 병렬 환경에서 ANYmal-C 보행을 학습하여, 75분 / 1,500 이터레이션 만에 평균 보상 +16.29에 도달합니다.
- **Sim-to-Real 정책 추출** — 학습된 정책을 TorchScript JIT(`.pt`)와 ONNX(`.onnx`)로 추출하여 TensorRT/Jetson을 통해 실제 로봇에 배포할 수 있습니다.
- **비용 최적화 운영** — CloudWatch GPU 유휴 감지가 30분 후 자동으로 인스턴스를 중지하며, S3 체크포인트 동기화가 Spot 중단에 대비합니다. Elastic IP 덕분에 중지/시작 후에도 SSH 접속 주소가 유지됩니다.

## 사전 요구 사항

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) 적절한 자격 증명으로 구성
- [NVIDIA NGC](https://ngc.nvidia.com/) API Key
- g6e 인스턴스 서비스 한도 승인 ([Service Quotas](https://console.aws.amazon.com/servicequotas/))
- EC2 접속용 SSH 키 페어

## 설치 방법

```bash
# 저장소 클론
git clone https://github.com/comeddy/pai-sim-isaaclab.git
cd pai-sim-isaaclab

# Terraform 변수 파일 복사 및 설정
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집 — NGC API Key, SSH 키, 리전 등 설정

# 인프라 초기화 및 배포 (~3분)
terraform init
terraform plan
terraform apply
```

## 사용법

### SSH 접속 및 부팅 확인

```bash
ssh -i your-key.pem ubuntu@$(terraform output -raw public_ip)

# 부트스트랩 진행 상황 모니터링 (15-25분)
tail -f /var/log/isaac-lab-setup.log
# "Isaac Lab setup COMPLETE" 메시지 확인
```

### 코어 isaaclab 패키지 설치 (최초 1회 필수)

```bash
docker run --name setup --gpus all \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  --entrypoint bash isaac-lab-base:latest -c '
    /workspace/isaaclab/_isaac_sim/python.sh -m pip install \
      --no-build-isolation -e /workspace/isaaclab/source/isaaclab
    cd /workspace/isaaclab && ./isaaclab.sh -i rsl_rl
  '
docker commit setup isaac-lab-ready:latest
docker rm setup
```

### PPO 훈련 실행

```bash
docker run --rm --gpus all --network=host \
  --entrypoint /workspace/isaaclab/isaaclab.sh \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  -v "/scratch/isaac-sim-cache/kit:/isaac-sim/kit/cache:rw" \
  -v "/data/checkpoints:/workspace/isaaclab/logs:rw" \
  isaac-lab-ready:latest \
  -p scripts/reinforcement_learning/rsl_rl/train.py \
    --task Isaac-Velocity-Rough-Anymal-C-v0 \
    --headless
# 1,500 이터레이션 기준 약 75분 소요
```

### Play 모드 실행 및 정책 추출

```bash
docker run --rm --gpus all --network=host \
  --entrypoint /workspace/isaaclab/isaaclab.sh \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  -v "/scratch/isaac-sim-cache/kit:/isaac-sim/kit/cache:rw" \
  -v "/data/checkpoints:/workspace/isaaclab/logs:rw" \
  isaac-lab-ready:latest \
  -p scripts/reinforcement_learning/rsl_rl/play.py \
    --task Isaac-Velocity-Rough-Anymal-C-v0 \
    --headless --video --video_length 1500 --num_envs 16 \
    --load_run <TIMESTAMP_DIR>
# 산출물: rl-video-step-0.mp4, exported/policy.pt, exported/policy.onnx
```

### 전체 리소스 정리

```bash
terraform destroy
```

## 환경 설정

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `aws_region` | AWS 리전 (g6e 인스턴스 지원 리전) | `us-east-1` |
| `project_name` | 리소스 네이밍 및 태깅용 프로젝트명 | `isaac-lab` |
| `isaac_lab_version` | Isaac Lab 릴리스 태그 | `v2.1.0` |
| `isaac_sim_version` | NGC의 Isaac Sim 컨테이너 태그 | `4.5.0` |
| `ngc_api_key` | NVIDIA NGC API 키 (민감 정보) | — |
| `root_volume_size_gb` | Root EBS 볼륨 크기 (OS + Docker 이미지) | `300` |
| `data_volume_size_gb` | Data EBS 볼륨 크기 (데이터셋 + 체크포인트) | `500` |
| `checkpoint_bucket` | 체크포인트 동기화용 S3 버킷명 접두사 (계정 ID 자동 접미사, Terraform이 버킷 생성) | `isaac-lab-checkpoints` |
| `enable_idle_stop` | GPU 30분 유휴 시 자동 중지 | `true` |
| `allowed_ssh_cidrs` | SSH 허용 CIDR 블록 | `["0.0.0.0/0"]` |

> **보안 참고**: `ngc_api_key`는 EC2 user data와 Terraform state에 평문으로 저장됩니다. 단기 워크샵 이상의 용도라면 키를 **AWS Secrets Manager**(또는 SSM Parameter Store)에 저장하고 인스턴스 롤을 통해 부팅 시 조회하는 방식을 권장합니다. `allowed_ssh_cidrs`도 기본 개방값 대신 본인 IP(`x.x.x.x/32`)로 제한하세요.

## 프로젝트 구조

```
pai-sim-isaaclab/
├── main.tf                       # Terraform: VPC, EC2, EBS, IAM, CloudWatch
├── variables.tf                  # 입력 변수 정의
├── outputs.tf                    # 출력 (IP, SSH 명령어)
├── terraform.tfvars.example      # 변수 템플릿 (terraform.tfvars로 복사)
├── user_data.sh                  # EC2 부트스트랩 (Docker, Isaac Lab 자동 설치)
├── docs/                         # 아키텍처 문서, ADR, 런북
│   ├── architecture.md           # 시스템 아키텍처 (이중 언어)
│   ├── decisions/                # Architecture Decision Records
│   ├── runbooks/                 # 운영 런북
│   └── onboarding.md            # 개발자 온보딩 가이드
├── workshop/                     # HonKit 워크샵 (7개 Lab + 3개 부록)
│   ├── SUMMARY.md               # 목차
│   ├── book.json                # HonKit 설정
│   └── chapters/                # Lab별 마크다운 콘텐츠
├── deck/                         # 워크샵 개요 덱 (standalone HTML 슬라이드)
├── models/                       # 학습된 정책 모델
│   ├── policy_jit.pt            # TorchScript JIT (C++ 추론용)
│   └── policy.onnx              # ONNX (TensorRT/Jetson 배포용)
├── videos/                       # Play 모드 녹화 영상
├── images/                       # 대시보드 스크린샷, 프레임 캡처
├── isaac_lab_dashboard.html      # Chart.js 훈련 메트릭 대시보드
├── scripts/                      # 설정 및 배포 스크립트
├── tests/                        # Harness 엔지니어링 테스트
└── .claude/                      # Claude Code 설정, hooks, skills
```

## 테스트

```bash
# 전체 harness 테스트 스위트 실행
bash tests/run-all.sh

# hook 테스트만 실행
bash tests/run-all.sh hooks

# structure 테스트만 실행
bash tests/run-all.sh structure

# Terraform 구성 검증
terraform validate
terraform fmt -check
```

## 기여 방법

1. 저장소를 Fork합니다
2. 기능 브랜치를 생성합니다 (`git checkout -b feat/amazing-feature`)
3. Conventional Commits로 커밋합니다 (`git commit -m 'feat: add amazing feature'`)
4. 브랜치에 Push합니다 (`git push origin feat/amazing-feature`)
5. Pull Request를 생성합니다

커밋 메시지 예시:

```
feat: add Spot instance support for cost optimization
fix: resolve EBS mount failure on Nitro instances
docs: update training parameters in Lab 4
```

## 라이선스

이 프로젝트의 Terraform 코드와 워크샵 문서는 [MIT License](LICENSE)로 공개됩니다. Isaac Sim / Isaac Lab은 [NVIDIA EULA](https://docs.omniverse.nvidia.com/isaacsim/latest/common/NVIDIA_Omniverse_License_Agreement.html)를 따릅니다.

## 연락처

- 메인테이너: [@comeddy](https://github.com/comeddy)
- 이슈: [GitHub Issues](https://github.com/comeddy/pai-sim-isaaclab/issues)

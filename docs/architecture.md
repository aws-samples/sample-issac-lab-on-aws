# Architecture

<a href="#english"><img src="https://img.shields.io/badge/lang-English-blue.svg" alt="English"></a>
<a href="#korean"><img src="https://img.shields.io/badge/lang-한국어-red.svg" alt="Korean"></a>

---

<a id="english"></a>

# English

## System Overview

pai-sim-isaaclab is an end-to-end pipeline for training quadruped locomotion policies using reinforcement learning on AWS GPU instances. Terraform provisions a g6e.4xlarge EC2 instance with NVIDIA L40S GPU, and user_data.sh bootstraps the NVIDIA Isaac Lab environment via Docker. A HonKit-based workshop guides users through 7 labs from infrastructure setup to Sim-to-Real deployment.

## Components

### Infrastructure Layer
- **main.tf** -- Single Terraform configuration defining VPC, subnet, EC2 (g6e.4xlarge), EBS volumes, IAM roles, and CloudWatch alarms. No module separation.
- **variables.tf** -- All input variables including NGC API key (sensitive), instance type, region.
- **outputs.tf** -- SSH commands, instance info, connection details.
- **user_data.sh** -- EC2 bootstrap script: mounts EBS/NVMe, pulls NGC images, builds Isaac Lab Docker, creates wrapper scripts.

### Compute Layer
- **EC2 g6e.4xlarge** -- NVIDIA L40S GPU, Deep Learning Base AMI (Ubuntu 22.04).
- **Root EBS (gp3)** -- Docker images and OS.
- **Data EBS (gp3)** -- Checkpoints and datasets.
- **Instance Store NVMe** -- Shader cache and scratch space.

### Monitoring Layer
- **CloudWatch Alarms** -- GPU idle detection (30min) triggers automatic EC2 Stop.
- **GPU Metrics Cron** -- 5-minute interval CloudWatch custom metric push.

### Presentation Layer
- **workshop/** -- HonKit (GitBook fork) with 7 labs + 3 appendices in Korean.
- **isaac_lab_dashboard.html** -- Chart.js training metrics dashboard.
- **presentation.html** -- Workshop presentation slides.

### AI/ML Layer
- **Isaac Lab (Docker)** -- NVIDIA Isaac Lab for robot simulation and RL training (PPO).
- **ANYmal-C** -- Quadruped robot model for locomotion policy training.
- **models/** -- Trained policies (policy_jit.pt, policy.onnx).

## Full Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Terraform (IaC)                           │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │main.tf   │    │variables │    │outputs   │              │
│  │          │    │.tf       │    │.tf       │              │
│  └────┬─────┘    └──────────┘    └──────────┘              │
│       │                                                     │
└───────┼─────────────────────────────────────────────────────┘
        ▼
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud (ap-northeast-2)                │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  VPC + Public Subnet + Internet Gateway              │   │
│  │                                                      │   │
│  │  ┌──────────────────────────────────┐                │   │
│  │  │  EC2 g6e.4xlarge (L40S GPU)     │                │   │
│  │  │                                  │                │   │
│  │  │  ┌────────────┐ ┌────────────┐  │                │   │
│  │  │  │ Isaac Lab  │ │ user_data  │  │                │   │
│  │  │  │ Docker     │ │ bootstrap  │  │                │   │
│  │  │  └────────────┘ └────────────┘  │                │   │
│  │  │                                  │                │   │
│  │  │  ┌─────┐ ┌──────┐ ┌─────────┐  │                │   │
│  │  │  │Root │ │Data  │ │NVMe     │  │                │   │
│  │  │  │EBS  │ │EBS   │ │Instance │  │                │   │
│  │  │  │gp3  │ │gp3   │ │Store    │  │                │   │
│  │  │  └─────┘ └──────┘ └─────────┘  │                │   │
│  │  └──────────────────────────────────┘                │   │
│  │                                                      │   │
│  │  ┌──────────┐  ┌───────────┐  ┌──────────┐          │   │
│  │  │CloudWatch│  │IAM Role   │  │S3        │          │   │
│  │  │Alarms    │  │(SSM+S3)   │  │Checkpoint│          │   │
│  │  └──────────┘  └───────────┘  └──────────┘          │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Workshop (HonKit)                         │
│                                                             │
│  Lab1─▶Lab2─▶Lab3─▶Lab4─▶Lab5─▶Lab6─▶Lab7                 │
│  Infra  EC2   Env   Train  Eval  S2R  Dashboard            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

```
Terraform -> AWS VPC -> EC2 (g6e.4xlarge) -> Docker (Isaac Lab)
  -> PPO Training -> policy_jit.pt -> S3 checkpoint sync
```

## Infrastructure

### Deployment Region
- ap-northeast-2 (Seoul)

### Resources
| Resource | Type | Description |
|----------|------|-------------|
| VPC | aws_vpc | /16 CIDR, single public subnet (no subnet-level public IP auto-assign) |
| EC2 | aws_instance | g6e.4xlarge, L40S GPU, no auto-assigned public IP |
| EIP | aws_eip | Stable SSH endpoint, survives idle-stop/start |
| KMS | aws_kms_key | Customer managed key (CMK) for EBS encryption, rotation enabled |
| EBS (Root) | aws_ebs_volume | gp3, Docker images, KMS CMK encrypted |
| EBS (Data) | aws_ebs_volume | gp3, checkpoints/datasets, KMS CMK encrypted |
| S3 (Checkpoints) | aws_s3_bucket | `{prefix}-{account_id}` name (globally unique, account-owned), public access blocked, force_destroy |
| IAM Role | aws_iam_role | SSM + S3 access (scoped to the Terraform-owned checkpoint bucket) |
| CloudWatch | aws_cloudwatch_metric_alarm | GPU idle auto-stop |

## Key Design Decisions

- **Single main.tf without modules** -- Workshop simplicity; participants can see the full infrastructure in one file without navigating module boundaries
- **g6e.4xlarge (L40S) over p-series** -- Cost-effective for RL training; L40S provides sufficient VRAM (48GB) at lower hourly cost than A100/H100
- **Docker source build for Isaac Lab** -- No official NGC image for Isaac Lab; source build with fallback ensures reproducibility
- **CloudWatch GPU idle auto-stop** -- Prevents runaway costs from forgotten instances during workshops
- **user_data.sh bootstrap** -- One-shot provisioning avoids configuration management complexity for a workshop environment

## Operations
- Deployment: see [docs/runbooks/](runbooks/) (create as needed)
- Infrastructure changes: `terraform plan` -> review -> `terraform apply`

---

<a id="korean"></a>

# 한국어

## 시스템 개요

pai-sim-isaaclab은 AWS GPU 인스턴스에서 강화학습을 사용하여 4족 보행 로봇의 운동 정책을 학습하는 엔드투엔드 파이프라인입니다. Terraform으로 g6e.4xlarge EC2 인스턴스(NVIDIA L40S GPU)를 프로비저닝하고, user_data.sh로 Docker 기반 NVIDIA Isaac Lab 환경을 부트스트랩합니다. HonKit 기반 워크샵이 인프라 설정부터 Sim-to-Real 배포까지 7개 Lab을 안내합니다.

## 컴포넌트

### 인프라 레이어
- **main.tf** -- VPC, 서브넷, EC2 (g6e.4xlarge), EBS 볼륨, IAM 역할, CloudWatch 알람을 정의하는 단일 Terraform 구성. 모듈 분리 없음.
- **variables.tf** -- NGC API 키(sensitive), 인스턴스 타입, 리전 등 모든 입력 변수.
- **outputs.tf** -- SSH 명령어, 인스턴스 정보, 연결 세부사항.
- **user_data.sh** -- EC2 부트스트랩 스크립트: EBS/NVMe 마운트, NGC 이미지 풀, Isaac Lab Docker 빌드, 래퍼 스크립트 생성.

### 컴퓨트 레이어
- **EC2 g6e.4xlarge** -- NVIDIA L40S GPU, Deep Learning Base AMI (Ubuntu 22.04).
- **Root EBS (gp3)** -- Docker 이미지 및 OS.
- **Data EBS (gp3)** -- 체크포인트 및 데이터셋.
- **Instance Store NVMe** -- 셰이더 캐시 및 스크래치 공간.

### 모니터링 레이어
- **CloudWatch 알람** -- GPU 30분 idle 감지 시 자동 EC2 중지.
- **GPU 메트릭 Cron** -- 5분 간격 CloudWatch 커스텀 메트릭 전송.

### 프레젠테이션 레이어
- **workshop/** -- HonKit (GitBook 포크) 기반 7개 Lab + 3개 부록 한국어 문서.
- **isaac_lab_dashboard.html** -- Chart.js 훈련 메트릭 대시보드.
- **presentation.html** -- 워크샵 프레젠테이션 슬라이드.

### AI/ML 레이어
- **Isaac Lab (Docker)** -- 로봇 시뮬레이션 및 RL 훈련(PPO)을 위한 NVIDIA Isaac Lab.
- **ANYmal-C** -- 4족 보행 로봇 모델.
- **models/** -- 학습된 정책 (policy_jit.pt, policy.onnx).

## 전체 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                    Terraform (IaC)                           │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │main.tf   │    │variables │    │outputs   │              │
│  │          │    │.tf       │    │.tf       │              │
│  └────┬─────┘    └──────────┘    └──────────┘              │
│       │                                                     │
└───────┼─────────────────────────────────────────────────────┘
        ▼
┌─────────────────────────────────────────────────────────────┐
│                    AWS 클라우드 (ap-northeast-2)              │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  VPC + 퍼블릭 서브넷 + 인터넷 게이트웨이               │   │
│  │                                                      │   │
│  │  ┌──────────────────────────────────┐                │   │
│  │  │  EC2 g6e.4xlarge (L40S GPU)     │                │   │
│  │  │                                  │                │   │
│  │  │  ┌────────────┐ ┌────────────┐  │                │   │
│  │  │  │ Isaac Lab  │ │ user_data  │  │                │   │
│  │  │  │ Docker     │ │ 부트스트랩  │  │                │   │
│  │  │  └────────────┘ └────────────┘  │                │   │
│  │  │                                  │                │   │
│  │  │  ┌─────┐ ┌──────┐ ┌─────────┐  │                │   │
│  │  │  │Root │ │Data  │ │NVMe     │  │                │   │
│  │  │  │EBS  │ │EBS   │ │Instance │  │                │   │
│  │  │  │gp3  │ │gp3   │ │Store    │  │                │   │
│  │  │  └─────┘ └──────┘ └─────────┘  │                │   │
│  │  └──────────────────────────────────┘                │   │
│  │                                                      │   │
│  │  ┌──────────┐  ┌───────────┐  ┌──────────┐          │   │
│  │  │CloudWatch│  │IAM Role   │  │S3        │          │   │
│  │  │알람      │  │(SSM+S3)   │  │체크포인트 │          │   │
│  │  └──────────┘  └───────────┘  └──────────┘          │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    워크샵 (HonKit)                           │
│                                                             │
│  Lab1─▶Lab2─▶Lab3─▶Lab4─▶Lab5─▶Lab6─▶Lab7                 │
│  인프라  EC2   환경   훈련  평가  S2R  대시보드              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 데이터 흐름 요약

```
Terraform -> AWS VPC -> EC2 (g6e.4xlarge) -> Docker (Isaac Lab)
  -> PPO 훈련 -> policy_jit.pt -> S3 체크포인트 동기화
```

## 인프라

### 배포 리전
- ap-northeast-2 (서울)

### 리소스
| 리소스 | 타입 | 설명 |
|--------|------|------|
| VPC | aws_vpc | /16 CIDR, 단일 퍼블릭 서브넷 (서브넷 레벨 public IP 자동 할당 비활성) |
| EC2 | aws_instance | g6e.4xlarge, L40S GPU, 자동 할당 public IP 없음 |
| EIP | aws_eip | 고정 SSH 엔드포인트, idle-stop/start 후에도 유지 |
| KMS | aws_kms_key | EBS 암호화용 고객 관리 키(CMK), 키 로테이션 활성화 |
| EBS (Root) | aws_ebs_volume | gp3, Docker 이미지, KMS CMK 암호화 |
| EBS (Data) | aws_ebs_volume | gp3, 체크포인트/데이터셋, KMS CMK 암호화 |
| S3 (체크포인트) | aws_s3_bucket | `{접두사}-{계정ID}` 이름 (글로벌 유일, 계정 소유), 퍼블릭 액세스 차단, force_destroy |
| IAM 역할 | aws_iam_role | SSM + S3 접근 (Terraform 소유 체크포인트 버킷으로 스코핑) |
| CloudWatch | aws_cloudwatch_metric_alarm | GPU idle 자동 중지 |

## 주요 설계 결정

- **모듈 분리 없는 단일 main.tf** -- 워크샵 단순성; 참가자가 모듈 경계를 탐색하지 않고 하나의 파일에서 전체 인프라를 볼 수 있음
- **p-시리즈 대신 g6e.4xlarge (L40S)** -- RL 훈련에 비용 효율적; L40S는 A100/H100보다 낮은 시간당 비용으로 충분한 VRAM(48GB) 제공
- **Isaac Lab Docker 소스 빌드** -- Isaac Lab 공식 NGC 이미지 없음; 소스 빌드와 fallback으로 재현성 보장
- **CloudWatch GPU idle 자동 중지** -- 워크샵 중 잊혀진 인스턴스로 인한 비용 폭주 방지
- **user_data.sh 부트스트랩** -- 원샷 프로비저닝으로 워크샵 환경의 구성 관리 복잡성 회피

## 운영
- 배포: [docs/runbooks/](runbooks/) 참조 (필요 시 생성)
- 인프라 변경: `terraform plan` -> 검토 -> `terraform apply`

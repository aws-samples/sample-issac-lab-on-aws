# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Physical AI 워크샵 프로젝트 — Terraform으로 AWS GPU 인스턴스(g6e.4xlarge, NVIDIA L40S)를 프로비저닝하고, NVIDIA Isaac Lab에서 ANYmal-C 4족 보행 로봇의 강화학습(PPO)을 실행하는 end-to-end 파이프라인.

- **로봇**: ANYmal-C (12관절 4족 보행)
- **환경**: Rough Terrain (바위, 경사면, 계단)
- **알고리즘**: PPO, 4,096개 병렬 환경
- **훈련 결과**: 75분, 1,500 iterations, 보상 -0.50 → +16.29
- **총 비용**: ~$12 (₩16,000)
- **주 언어**: 한국어 (문서/코드 주석), HCL/Bash/Python (코드)

---

## Repository Structure

```
pai-sim-isaaclab/
├── main.tf                      # Terraform 전체 인프라 (단일 파일)
├── variables.tf                 # 입력 변수 정의
├── outputs.tf                   # 출력 (IP, SSH 명령어, 스펙 요약)
├── terraform.tfvars.example     # 변수 템플릿 (복사해서 terraform.tfvars로 사용)
├── user_data.sh                 # EC2 부트스트랩 (Terraform templatefile()로 렌더링)
│
├── CLAUDE.md                    # AI 어시스턴트 가이드 (이 파일)
├── README.md                    # 프로젝트 설명 (한국어)
├── SUMMARY.md                   # 빠른 목차
├── REPORT_Physical_AI_on_AWS.md # 종합 실습 리포트
│
├── workshop/                    # HonKit(GitBook) 기반 워크샵
│   ├── book.json                # HonKit 설정 (title, language=ko)
│   ├── package.json             # npm 의존성 (honkit v6.1.7)
│   ├── SUMMARY.md               # 책 목차 (7 Lab + 3 Appendix)
│   ├── README.md                # 워크샵 소개
│   ├── assets/                  # 스크린샷 & 다이어그램
│   └── chapters/
│       ├── 01-concepts.md       # Physical AI 핵심 개념
│       ├── 02-infrastructure.md # AWS GPU 인프라 구축
│       ├── 03-docker-build.md   # Isaac Lab Docker 빌드
│       ├── 04-training.md       # 강화학습 훈련 실행
│       ├── 05-results.md        # 학습 결과 분석
│       ├── 06-play-mode.md      # Play 모드 & Policy Export
│       ├── 07-cleanup.md        # 정리 및 다음 단계
│       ├── appendix-a-troubleshooting.md  # 실전 트러블슈팅 12선
│       ├── appendix-b-cost.md   # 비용 분석 & 최적화
│       └── appendix-c-references.md       # 소프트웨어 버전 & 참고자료
│
├── deck/                         # 워크샵 개요 덱 (claude.ai/design에서 import, deck-stage.js 기반 standalone HTML)
│   ├── index.html                # 5슬라이드 덱 (Title/개요/파이프라인/데모/Thanks)
│   ├── deck-stage.js             # 프레젠테이션 웹 컴포넌트 (키보드 내비, 스케일링, 인쇄)
│   ├── assets/logo-aws.png       # AWS 로고
│   └── fonts/AmazonEmber_*.ttf   # Amazon Ember 폰트 4종 (Rg/Md/Bd/He)
├── models/
│   ├── policy_jit.pt            # TorchScript JIT (C++ 실시간 추론용)
│   └── policy.onnx              # ONNX (TensorRT/Jetson GPU 배포용)
├── videos/
│   ├── anymal_c_play.mp4        # 10초 테스트 영상
│   └── anymal_c_play_30s.mp4    # 30초 최종 영상
├── images/                      # 대시보드 스크린샷, Play 모드 프레임
├── isaac_lab_dashboard.html     # Chart.js 기반 훈련 메트릭 대시보드
├── presentation.html            # HTML 슬라이드쇼
├── Physical_AI_Workshop.pptx    # PowerPoint 발표 자료 (14장)
└── generate_pptx.py             # PowerPoint 생성 스크립트
```

---

## Commands

### Terraform (인프라)

```bash
# 처음 시작 시
cp terraform.tfvars.example terraform.tfvars  # 변수 파일 생성 후 편집
terraform init           # 프로바이더 초기화 (처음 한 번)

# 일상 작업
terraform validate       # HCL 구문 검증
terraform fmt            # HCL 포맷팅 (자동 정렬)
terraform fmt -check     # 포맷 검사 (CI용, 변경 없이 오류 코드만 반환)
terraform plan           # 변경 사항 미리보기
terraform apply          # 인프라 배포 (~3분)
terraform destroy        # 전체 리소스 삭제 (훈련 완료 후 필수)

# 배포 후 SSH
terraform output ssh_command         # SSH 명령어 출력
terraform output -raw ssh_private_key > isaac-lab-key.pem  # 자동 생성 키 저장
chmod 400 isaac-lab-key.pem
```

### GitBook 워크샵 (workshop/)

```bash
cd workshop
npm install              # 의존성 설치 (honkit v6.1.7)
npx honkit serve         # http://localhost:4000 로컬 서버
npx honkit build         # _book/ 정적 빌드 (배포용)
```

### EC2 접속 후 훈련 명령어

```bash
# GPU 상태 확인
nvidia-smi

# 훈련 실행 (isaac-lab-run 래퍼 스크립트)
isaac-lab-run source/standalone/workflows/rsl_rl/train.py \
  --task Isaac-Velocity-Rough-Anymal-C-v0 --headless

# 대화형 Isaac Sim 셸
isaac-sim-shell

# 체크포인트 S3 수동 동기화
sync-checkpoints

# 로그 모니터링
tail -f /data/logs/isaac-lab.log
tail -f /var/log/isaac-lab-setup.log  # 부트스트랩 로그
```

### Docker (직접 실행)

```bash
# NGC 로그인
echo "$NGC_API_KEY" | docker login nvcr.io --username '$oauthtoken' --password-stdin

# Isaac Sim 이미지 pull
docker pull nvcr.io/nvidia/isaac-sim:4.5.0

# Isaac Lab 소스 빌드 (NGC 공식 이미지 없음)
cd /opt/isaaclab
docker compose --profile base build

# isaaclab 패키지 수동 설치 (빌드 후 필수)
pip install --no-build-isolation -e source/isaaclab

# 훈련 직접 실행 (entrypoint 반드시 오버라이드)
docker run --rm --gpus all --network=host \
  --entrypoint /workspace/isaaclab/isaaclab.sh \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  -v /scratch/isaac-sim-cache/kit:/isaac-sim/kit/cache:rw \
  -v /data/checkpoints:/workspace/isaaclab/logs:rw \
  isaac-lab-base:latest \
  -p source/standalone/workflows/rsl_rl/train.py \
  --task Isaac-Velocity-Rough-Anymal-C-v0 --headless
```

---

## Architecture

### Terraform 레이어 (루트 디렉토리)

단일 `main.tf`에 전체 인프라를 정의 (모듈 분리 없음). 필요한 Terraform >= 1.5.0, AWS Provider >= 5.0.

| 컴포넌트 | 리소스 | 세부 사항 |
|---------|--------|---------|
| Networking | VPC → IGW → Subnet → Route Table | CIDR 10.0.0.0/16, 퍼블릭 서브넷 10.0.1.0/24 (public IP 자동 할당 비활성) |
| Security | Security Group | SSH(22) 인바운드, 전체 아웃바운드 |
| Compute | g6e.4xlarge EC2 | 1× L40S 48GB, 16 vCPU, 128 GiB RAM (자동 할당 public IP 없음) |
| EIP | Elastic IP | SSH 접속 엔드포인트, stop/start 후에도 IP 고정 |
| AMI | Deep Learning Base OSS Nvidia Driver (Ubuntu 22.04) | NVIDIA 드라이버, CUDA, Docker 사전 설치 |
| KMS | CMK + Alias | EBS 암호화용 고객 관리 키, 키 로테이션 활성화 |
| Root EBS | gp3, 300GB, 6000 IOPS, 500 MB/s, KMS CMK 암호화 | OS + Docker 이미지 |
| Data EBS | gp3, 500GB, 6000 IOPS, 500 MB/s, KMS CMK 암호화 | 데이터셋, 체크포인트 (`/data`) |
| Instance Store | 600GB NVMe (자동 부착) | 셰이더 캐시, 스크래치 (`/scratch`) |
| S3 | 체크포인트 버킷 | Terraform이 `{접두사}-{계정ID}` 이름으로 생성 (네임스쿼팅 방지), 퍼블릭 액세스 차단, `force_destroy = true` |
| IAM | EC2 Role + Instance Profile | S3 체크포인트 접근 (Terraform 소유 버킷 ARN으로 스코핑) + SSM Session Manager |
| Monitoring | CloudWatch Alarm | GPU 30분 idle(< 5%) → 인스턴스 자동 Stop |
| SSH Key | ED25519 자동 생성 또는 기존 키 사용 | `existing_key_name` 또는 `ssh_public_key` 변수로 제어 |
| Metadata | IMDSv2 전용 | `http_tokens = "required"` |

**지원 리전** (`aws_region` 유효성 검사):
`us-east-1`, `us-east-2`, `us-west-2`, `eu-central-1`, `eu-north-1`, `ap-northeast-1`, `ap-northeast-2`

### Variables 참조 (variables.tf)

| 변수 | 기본값 | 필수 | 설명 |
|-----|--------|------|------|
| `aws_region` | `us-east-1` | — | g6e 지원 리전 |
| `project_name` | `isaac-lab` | — | 리소스 이름/태그 접두사 |
| `isaac_lab_version` | `v2.1.0` | — | Isaac Lab 릴리스 태그 |
| `isaac_sim_version` | `4.5.0` | — | Isaac Sim NGC 컨테이너 태그 |
| `ngc_api_key` | — | **필수** | NGC API 키 (`sensitive = true`) |
| `existing_key_name` | `""` | — | 기존 AWS 키 페어 이름 |
| `ssh_public_key` | `""` | — | SSH 공개키 내용 (비우면 자동 생성) |
| `allowed_ssh_cidrs` | `["0.0.0.0/0"]` | — | SSH 허용 CIDR (자신의 IP로 제한 권장) |
| `root_volume_size_gb` | `300` | — | 루트 EBS 크기 (GB) |
| `data_volume_size_gb` | `500` | — | 데이터 EBS 크기 (GB) |
| `checkpoint_bucket` | `isaac-lab-checkpoints` | — | S3 버킷 이름 접두사 (계정 ID 자동 접미사, Terraform이 버킷 생성) |
| `enable_idle_stop` | `true` | — | GPU idle 자동 Stop 활성화 |
| `spot_max_price` | `"2.50"` | — | Spot 최대 시간당 가격 (블록 주석 해제 시) |

### user_data.sh — EC2 부트스트랩

`main.tf`의 `templatefile("${path.module}/user_data.sh", {...})`로 렌더링. 전체 로그: `/var/log/isaac-lab-setup.log`

**실행 단계 (순서대로)**:

1. **시스템 패키지** — unattended-upgrades 중지, dpkg lock 재시도(12회), `awscli jq htop nvtop tree unzip build-essential` 설치
2. **Data EBS 마운트** — Nitro NVMe 장치 동적 탐색, ext4 포맷, `/data` 마운트, 서브디렉토리 생성 (`datasets/`, `checkpoints/`, `logs/`, `cache/`)
3. **Instance Store NVMe 마운트** — `/opt/dlami/nvme` 재활용 또는 직접 탐색 → `/scratch` 마운트
4. **NVIDIA 드라이버 & Docker 검증** — `nvidia-smi` 실패 시 즉시 종료
5. **NGC 로그인 + Isaac Sim pull** — `nvcr.io/nvidia/isaac-sim:{isaac_sim_version}` (로그인 실패는 비치명적 — 이미지가 공개라 익명 pull로 계속 진행)
6. **Isaac Lab pull/빌드** — NGC 이미지 시도 → 실패 시 소스 클론(`/opt/isaaclab`) + `echo n | docker/container.py start base` (X11 프롬프트 자동 응답, v2.1.0에 `--no-enter` 플래그 없음)
7. **래퍼 스크립트 생성** (`/usr/local/bin/`):
   - `isaac-lab-run`: GPU 볼륨 마운트, 캐시 설정 포함 헤드리스 훈련
   - `isaac-sim-shell`: Isaac Sim 대화형 bash
   - `sync-checkpoints`: S3 동기화
8. **Cron 등록**: 체크포인트 동기화 30분마다, GPU 메트릭 CloudWatch 5분마다
9. **GPU 모니터링** — `/opt/gpu_monitor.sh`: IMDSv2로 인스턴스 ID 조회, `GPUUtilization/GPUMemoryUtilization/GPUTemperature` → `CWAgent` 네임스페이스

### 워크샵 (workshop/)

HonKit(GitBook fork) 기반 7개 Lab + 3개 Appendix 한국어 문서.

| 챕터 | 내용 | 예상 시간 |
|------|------|---------|
| Lab 1 | Physical AI 핵심 개념 (sim-to-real, RL 루프) | 10분 |
| Lab 2 | AWS GPU 인프라 구축 (Terraform 배포) | 20분 |
| Lab 3 | Isaac Lab Docker 이미지 빌드 | 30분 |
| Lab 4 | PPO 강화학습 훈련 실행 (1,500 iter) | 75분 |
| Lab 5 | 학습 결과 분석 (대시보드, 커브) | 15분 |
| Lab 6 | Play 모드 & Policy Export (JIT, ONNX) | 10분 |
| Lab 7 | 정리 및 다음 단계 | 10분 |
| Appendix A | 실전 트러블슈팅 12선 | 참고 |
| Appendix B | 비용 분석 & 최적화 | 참고 |
| Appendix C | 소프트웨어 버전 & 참고자료 | 참고 |

---

## Key Gotchas

### Terraform templatefile() 변수 이스케이프 (가장 흔한 실수)

`user_data.sh`는 `templatefile()`로 렌더링됨. 두 종류의 변수를 혼동하면 렌더링 실패:

```bash
# Terraform 변수 (templatefile이 치환) — 단일 달러
NGC_KEY="${ngc_api_key}"
ISAAC_SIM_IMAGE="nvcr.io/nvidia/isaac-sim:${isaac_sim_version}"
aws s3 sync /data/checkpoints/ "s3://${checkpoint_bucket}/$(hostname)/"

# 셸 변수 (런타임에 평가) — 이중 달러 이스케이프
nvcr.io/nvidia/isaac-sim:$${ISAAC_SIM_TAG:-4.5.0}
```

### Isaac Lab Docker 이미지

- NGC에 공식 Isaac Lab 이미지가 없으므로 소스 빌드 필수:
  ```bash
  cd /opt/isaaclab
  docker compose --profile base build
  ```
- 빌드 후 `isaaclab` 패키지가 site-packages에 설치되지 않음:
  ```bash
  pip install --no-build-isolation -e source/isaaclab
  ```

### Docker Entrypoint 오버라이드

기본 entrypoint(`runheadless.sh`)는 스트리밍 서버 모드로 시작 → 훈련에 사용 불가:
```bash
# 반드시 isaaclab.sh로 오버라이드
docker run --entrypoint /workspace/isaaclab/isaaclab.sh isaac-lab-base:latest -p <script.py>
```

### Nitro NVMe 장치 명명

g6e 인스턴스(Nitro)에서 EBS 볼륨은 `/dev/xvdf`가 아닌 `/dev/nvme*n1`로 나타남. `user_data.sh`의 `find_data_device()` 함수가 루트 볼륨과 Instance Store를 제외하고 동적으로 탐색함.

Instance Store 구분: `nvme id-ctrl` 출력에서 "Amazon Elastic Block Store" 문자열 없으면 Instance Store.

### 민감 정보 보안

- `terraform.tfvars`는 `.gitignore`에 포함되어 있음 — 커밋 방지됨
- `ngc_api_key`는 `sensitive = true` — `terraform output`으로 평문 노출 안 됨
- 단, `ngc_api_key`는 user data와 tfstate에는 평문 렌더링됨 — 워크샵 이상의 용도라면 Secrets Manager/SSM Parameter Store에 저장하고 인스턴스 롤로 부팅 시 조회 권장
- `ssh_private_key` 출력도 `sensitive = true`
- `terraform.tfvars.example`에는 실제 키 절대 기입 금지

### Spot 인스턴스 활성화

`main.tf` 하단의 `instance_market_options` 블록 주석 해제:
```hcl
instance_market_options {
  market_type = "spot"
  spot_options {
    max_price          = var.spot_max_price  # 기본 "2.50"
    spot_instance_type = "persistent"
  }
}
```
온디맨드 ~$3/hr vs Spot ~$0.83/hr (약 72% 절감).

### AMI 변경 무시

`lifecycle { ignore_changes = [ami] }` — `terraform apply` 재실행 시 AMI 업데이트로 인한 인스턴스 재생성 방지.

---

## Training Workflow

1. `terraform.tfvars` 작성 (NGC API 키, 본인 IP를 `allowed_ssh_cidrs`에 설정)
2. `terraform apply` — VPC, EC2, EBS 생성 (~3분)
3. SSH 접속 후 부트스트랩 완료 대기 (`tail -f /var/log/isaac-lab-setup.log`)
4. `nvidia-smi`로 GPU 확인
5. 훈련 실행: `isaac-lab-run source/standalone/workflows/rsl_rl/train.py --task Isaac-Velocity-Rough-Anymal-C-v0 --headless`
6. 체크포인트 `/data/checkpoints/`에 자동 저장, 30분마다 S3 동기화
7. 학습 완료 후 Play 모드: JIT/ONNX 정책 export
8. `terraform destroy` — 모든 리소스 삭제 (비용 절감)

---

## Git & Branch

- **기본 브랜치**: `master`
- **개발 브랜치**: `claude/add-claude-documentation-f3NbX`
- **리모트**: `origin` (GitHub, comeddy/pai-sim-isaaclab)

`.gitignore` 제외 항목: `*.pem`, `*.key`, `terraform.tfvars`, `.env`, `*.tfstate`, `.terraform/`, `.terraform.lock.hcl`, `_book/`, `node_modules/`, OS/IDE 파일.

---

## Cost Management

| 항목 | 비용 |
|------|------|
| g6e.4xlarge 온디맨드 | ~$3.00/hr |
| g6e.4xlarge Spot | ~$0.83/hr |
| Data EBS (500GB gp3) | ~$0.08/GB/월 |
| S3 체크포인트 | ~$0.023/GB/월 |
| **워크샵 총 비용** | **~$12** |

비용 최적화:
- `enable_idle_stop = true`: GPU 30분 idle 시 자동 Stop
- Spot 인스턴스 블록 주석 해제: 72% 절감
- `terraform destroy`: 사용 후 즉시 삭제
- 체크포인트 S3 동기화: Spot 인터럽트 대비
## Project Structure

```
.claude/        - Claude 설정, hooks, skills, commands, agents
docs/           - Architecture docs, ADRs, runbooks
  decisions/    - Architecture Decision Records
  runbooks/     - Operational runbooks
scripts/        - 프로젝트 설정/배포 스크립트
tests/          - Harness 엔지니어링 테스트
workshop/       - HonKit 워크샵 문서
models/         - 학습된 정책 파일
videos/         - Play 모드 녹화
images/         - 스크린샷, 프레임 캡처
```

---

## Auto-Sync Rules

Rules below are applied automatically after Plan mode exit and on major code changes.

### Post-Plan Mode Actions
After exiting Plan mode (`/plan`), before starting implementation:

1. **Architecture decision made** -> Update `docs/architecture.md`
2. **Technical choice/trade-off made** -> Create `docs/decisions/ADR-NNN-title.md`
3. **New module added** -> Create `CLAUDE.md` in that module directory
4. **Operational procedure defined** -> Create runbook in `docs/runbooks/`
5. **Changes needed in this file** -> Update relevant sections above

### Code Change Sync Rules
- Terraform 파일 변경 -> `docs/architecture.md` Infrastructure 섹션 업데이트
- `user_data.sh` 변경 -> CLAUDE.md의 user_data.sh 섹션 업데이트
- Workshop 챕터 추가/변경 -> `workshop/CLAUDE.md` 업데이트
- 인프라 변경 -> `docs/architecture.md` 업데이트

### ADR Numbering
Find the highest number in `docs/decisions/ADR-*.md` and increment by 1.
Format: `ADR-NNN-concise-title.md`

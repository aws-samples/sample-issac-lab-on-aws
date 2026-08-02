# Lab 2: AWS GPU 인프라 구축

> ℹ️ <b>INFO</b>
>
> <b>소요 시간</b>: 약 20분
> <b>목표</b>: Terraform으로 Isaac Lab 훈련용 EC2 GPU 인스턴스를 프로비저닝합니다.

---

## 2.1 Terraform이란?

인프라를 <b>코드</b>로 정의하는 도구입니다.

```
AWS 콘솔 클릭 (수동)          Terraform (코드)
─────────────────────       ─────────────────────
재현 불가능                   git으로 버전 관리
누가 뭘 바꿨는지 모름          변경 이력 추적 가능
정리할 때 리소스 빠뜨림         terraform destroy로 일괄 삭제
```

---

## 2.2 프로젝트 구조

```
pai-sim-isaaclab/
├── main.tf              # 핵심: VPC, EC2, EBS, IAM, CloudWatch
├── variables.tf         # 입력 변수 정의
├── outputs.tf           # 출력 (IP, SSH 명령어)
├── terraform.tfvars     # 실제 값 (gitignore 대상!)
└── user_data.sh         # EC2 부팅 시 자동 실행 스크립트
```

---

## 2.3 사전 준비

### NGC API Key 발급

1. [NGC](https://ngc.nvidia.com/) 접속 → 로그인
2. 우측 상단 프로필 → `Setup` → `Generate API Key`
3. Key를 안전하게 보관

### SSH Key Pair 생성

```bash
# AWS에서 사용할 키 페어 생성 (이미 있으면 skip)
aws ec2 create-key-pair \
  --key-name <KEY_NAME> \
  --query 'KeyMaterial' \
  --output text > <KEY_NAME>.pem
chmod 400 <KEY_NAME>.pem
```

---

## 2.4 변수 설정

`terraform.tfvars` 파일을 생성합니다:

```hcl
# terraform.tfvars — 본인 환경에 맞게 수정
aws_region       = "ap-northeast-2"      # Seoul 리전
key_name         = "<KEY_NAME>"          # SSH 키 이름
instance_type    = "g6e.4xlarge"         # 1x L40S 48GB
ngc_api_key      = "nvapi-YOUR_KEY_HERE" # NGC API Key
allowed_ssh_cidrs = ["YOUR.IP.ADDR/32"]  # 본인 IP만 허용
s3_bucket_name   = "isaac-sim-results-ACCOUNT_ID"
root_volume_size = 300                   # GB (Isaac Sim 23GB + Lab 25GB + 여유)
data_volume_size = 500                   # GB (체크포인트 저장)
enable_idle_stop = true                  # GPU 유휴 30분 시 자동 중지
```

> 🚨 <b>DANGER</b>
>
> <b>보안</b>: `terraform.tfvars`에 NGC API Key와 같은 시크릿이 포함됩니다. 반드시 `.gitignore`에 추가하세요. 프로덕션에서는 AWS Secrets Manager를 사용하세요.

---

## 2.5 핵심 리소스 이해

### AMI (Amazon Machine Image)

```hcl
data "aws_ami" "dl_base" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04) *"]
  }
}
```

> ⚠️ <b>WARNING</b>
>
> <b>왜 Deep Learning Base OSS AMI인가?</b>
> - NVIDIA 드라이버, Docker, NVIDIA Container Toolkit이 <b>이미 설치</b>되어 있음
> - Isaac Sim은 Docker 컨테이너로 실행하므로, 무거운 PyTorch DLAMI는 불필요
> - AMI ID는 리전/시점마다 다르므로 <b>절대 하드코딩하지 말 것</b> → `data` 소스로 동적 조회

### EC2 인스턴스

```hcl
resource "aws_instance" "isaac" {
  ami           = data.aws_ami.dl_base.id
  instance_type = var.instance_type   # g6e.4xlarge

  root_block_device {
    volume_size = 300          # Isaac Sim(23GB) + Lab(25GB) + Docker layers
    volume_type = "gp3"
    iops        = 6000
    throughput  = 500          # MB/s — Docker build 시 I/O 집중
    encrypted   = true
  }

  user_data = base64encode(templatefile("user_data.sh", {
    ngc_api_key       = var.ngc_api_key
    isaac_sim_version = "4.5.0"
    isaac_lab_version = "v2.1.0"
  }))
}
```

### 인스턴스 사이징 가이드

| 인스턴스 | GPU | VRAM | 용도 | 시간당 비용 |
|----------|-----|------|------|------------|
| g6e.xlarge | 1× L40S | 48 GB | 개발/디버깅 | ~$1.00 |
| <b>g6e.4xlarge</b> | <b>1× L40S</b> | <b>48 GB</b> | <b>표준 RL 훈련</b> | <b>~$3.00</b> |
| g6e.12xlarge | 4× L40S | 192 GB | 대규모 훈련 | ~$8.00 |
| g6e.48xlarge | 8× L40S | 384 GB | 분산 훈련 | ~$32.00 |

### 데이터 볼륨 (EBS)

```hcl
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.isaac.availability_zone
  size              = 500         # GB
  type              = "gp3"
  encrypted         = true
  tags = { Name = "isaac-data" }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.isaac.id
}
```

> ℹ️ <b>INFO</b>
>
> <b>왜 별도 EBS?</b> 인스턴스를 삭제해도 체크포인트가 보존됩니다. root 볼륨은 `delete_on_termination = true`이지만, 데이터 볼륨은 독립적으로 유지됩니다.

### 비용 절약: GPU 유휴 자동 중지

```hcl
resource "aws_cloudwatch_metric_alarm" "gpu_idle" {
  alarm_name          = "isaac-gpu-idle-stop"
  comparison_operator = "LessThanThreshold"
  threshold           = 5          # GPU 사용률 5% 미만
  period              = 300        # 5분 간격 체크
  evaluation_periods  = 6          # 6회 연속 = 30분

  alarm_actions = [
    "arn:aws:automate:${var.aws_region}:ec2:stop"
  ]
}
```

훈련 완료 후 GPU가 30분 이상 유휴 상태이면 자동으로 인스턴스가 <b>중지</b>(Stop)됩니다.

---

## 2.6 인프라 배포

```bash
# 1. 초기화 — 프로바이더 다운로드
terraform init

# 2. 계획 — 무엇이 생성되는지 미리보기
terraform plan

# 3. 배포 — 실제 인프라 생성 (~3분)
terraform apply
```

### 배포 결과 확인

```bash
# Terraform 출력
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:
  instance_id = "<INSTANCE_ID>"
  public_ip   = "<PUBLIC_IP>"
  ssh_command = "ssh -i <KEY_NAME>.pem ubuntu@<PUBLIC_IP>"
```

---

## 2.7 SSH 접속 및 부팅 확인

```bash
# SSH 접속
ssh -i <KEY_NAME>.pem ubuntu@<PUBLIC_IP>

# user_data.sh 실행 로그 확인 (부팅 스크립트)
tail -f /var/log/isaac-lab-setup.log
```

> ⚠️ <b>WARNING</b>
>
> <b>주의</b>: `user_data.sh`는 Docker 이미지 pull, Isaac Lab 빌드 등 무거운 작업을 수행합니다. 완료까지 <b>15-25분</b> 소요됩니다. 로그에 `Isaac Lab setup COMPLETE`가 나올 때까지 기다리세요.

### GPU 동작 확인

```bash
nvidia-smi
# NVIDIA L40S, 48 GB VRAM이 표시되어야 합니다

docker images | grep isaac
# nvcr.io/nvidia/isaac-sim:4.5.0   ~22.6GB
```

---

## 2.8 Security Group 확인

```hcl
# 최소 필수 포트만 개방
ingress {
  from_port   = 22      # SSH
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.allowed_ssh_cidrs   # 본인 IP만!
}

egress {
  from_port   = 0       # 아웃바운드 전체 허용 (NGC pull, S3 sync)
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

> 🚨 <b>DANGER</b>
>
> <b>절대 0.0.0.0/0으로 SSH를 열지 마세요.</b> 반드시 `allowed_ssh_cidrs`에 본인 IP만 지정하세요. `curl ifconfig.me`로 현재 IP를 확인할 수 있습니다.

---

## 체크포인트

- [ ] `terraform apply` 성공, 인스턴스 실행 중
- [ ] SSH 접속 가능
- [ ] `nvidia-smi`에서 L40S GPU 확인
- [ ] `/var/log/isaac-lab-setup.log`에서 부팅 스크립트 진행 확인

---

👈 [Lab 1: Physical AI 핵심 개념](01-concepts.md)
👉 [Lab 3: Isaac Lab Docker 이미지 빌드](03-docker-build.md)

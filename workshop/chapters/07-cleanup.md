# Lab 7: 정리 및 다음 단계

> ℹ️ <b>INFO</b>
>
> <b>소요 시간</b>: 약 10분
> <b>목표</b>: AWS 리소스를 정리하고, 후속 학습 경로를 안내합니다.

---

## 7.1 리소스 정리

> 🚨 <b>DANGER</b>
>
> <b>반드시 실행하세요.</b> g6e.4xlarge는 시간당 ~$3 과금됩니다. 워크샵 완료 후 리소스를 삭제하지 않으면 불필요한 비용이 발생합니다.

### 체크포인트 백업 (삭제 전)

```bash
# S3에 최종 결과물 백업
aws s3 sync /data/checkpoints/ s3://YOUR_BUCKET/final-backup/ \
  --exclude "*.tmp"

# 로컬에 핵심 파일만 다운로드
scp -i <KEY_NAME>.pem ubuntu@<IP>:/data/checkpoints/rsl_rl/anymal_c_rough/*/model_1499.pt .
scp -i <KEY_NAME>.pem ubuntu@<IP>:/data/checkpoints/rsl_rl/anymal_c_rough/*/exported/* .
scp -i <KEY_NAME>.pem ubuntu@<IP>:/data/checkpoints/rsl_rl/anymal_c_rough/*/videos/play/*.mp4 .
```

### Terraform Destroy

```bash
# 모든 AWS 리소스 일괄 삭제
terraform destroy

# 확인 메시지가 나오면 "yes" 입력
# Plan: 0 to add, 0 to change, 12 to destroy.
# Do you really want to destroy all resources? yes
```

### 삭제되는 리소스

| 리소스 | 설명 |
|--------|------|
| EC2 Instance | g6e.4xlarge GPU 인스턴스 |
| EBS Volumes | root (300GB) + data (500GB) |
| VPC | 서브넷, 인터넷 게이트웨이, 라우팅 테이블 |
| Security Group | SSH + DCV 포트 규칙 |
| IAM Role/Profile | S3/CloudWatch 접근 권한 |
| CloudWatch Alarm | GPU 유휴 감지 |
| S3 Bucket | 체크포인트 저장소 (비어있지 않으면 수동 삭제 필요) |

> ⚠️ <b>WARNING</b>
>
> <b>S3 버킷</b>: `terraform destroy`는 비어있지 않은 S3 버킷을 삭제하지 못할 수 있습니다. `aws s3 rb s3://BUCKET_NAME --force`로 수동 삭제하세요.

---

## 7.2 이번 워크샵에서 달성한 것

```
✅ Terraform으로 AWS GPU 인프라를 코드로 구축
✅ Isaac Sim + Isaac Lab Docker 이미지를 빌드 (26.8 GB)
✅ 4,096개 병렬 환경에서 PPO 강화학습 실행
✅ 75분 만에 1.47억 timestep 학습 완료
✅ ANYmal-C가 rough terrain에서 안정적으로 보행
✅ 학습된 정책을 JIT/ONNX로 export (sim-to-real 준비)
✅ 총 비용: ~$12 (₩16,000)
```

---

## 7.3 다음 단계

### Level 1: 다른 로봇 실험

```bash
# Unitree Go2 (소형 4족 로봇)
--task Isaac-Velocity-Rough-Unitree-Go2-v0

# Humanoid H1 (2족 보행)
--task Isaac-Velocity-Rough-H1-v0

# 로봇 팔 (매니퓰레이션)
--task Isaac-Lift-Cube-Franka-v0
```

### Level 2: 하이퍼파라미터 튜닝

```yaml
# 더 많은 환경 (VRAM 여유 있음: 10GB / 48GB)
num_envs: 8192

# 더 긴 학습 (아직 완전히 수렴하지 않음)
max_iterations: 3000

# 빠른 수렴을 위한 초기 노이즈 축소
init_noise_std: 0.5
```

### Level 3: Sim-to-Real Transfer

시뮬레이션→실제 환경 전이의 핵심 기법:

1. <b>Domain Randomization</b>: 물리 파라미터를 랜덤하게 변경하며 학습
   - 질량 ±20%, 마찰 ±30%, 관절 강성 ±15%
   - 시뮬레이션과 실제의 gap을 줄이는 핵심 기법

2. <b>System Identification</b>: 실제 로봇의 물리 파라미터를 정밀 측정
   - 시뮬레이션의 정확도를 높여 sim-to-real gap 최소화

3. <b>Real-World Fine-tuning</b>: 시뮬레이션 정책을 실제 환경에서 미세 조정

### Level 4: Multi-GPU 분산 훈련

```bash
# g6e.12xlarge (4× L40S)로 스케일업
terraform.tfvars:
  instance_type = "g6e.12xlarge"

# 분산 훈련 실행
torchrun --nnodes=1 --nproc_per_node=4 train.py --distributed
```

### Level 5: Custom 환경 제작

자사 로봇의 URDF/USD 모델을 Isaac Lab에 통합:

1. CAD → URDF → USD 변환
2. Isaac Lab 환경 클래스 작성
3. 보상 함수 설계 (reward engineering)
4. 커리큘럼 학습 설정

---

## 7.4 참고 자료

| 자료 | 링크 |
|------|------|
| Isaac Lab 공식 문서 | https://isaac-sim.github.io/IsaacLab/ |
| Isaac Sim NGC 카탈로그 | https://catalog.ngc.nvidia.com/orgs/nvidia/containers/isaac-sim |
| RSL-RL 라이브러리 | https://github.com/leggedrobotics/rsl_rl |
| PPO 원논문 | Schulman et al., "Proximal Policy Optimization Algorithms" (2017) |
| ANYmal 논문 | Hwangbo et al., "Learning agile and dynamic motor skills for legged robots" (2019) |
| AWS g6e 인스턴스 | https://aws.amazon.com/ec2/instance-types/g6e/ |
| Terraform AWS Provider | https://registry.terraform.io/providers/hashicorp/aws/ |

---

## 7.5 워크샵 피드백

이 워크샵에서:
- 가장 도움이 된 부분은?
- 가장 어려웠던 부분은?
- 추가로 다뤄줬으면 하는 내용은?

---

> ✅ <b>SUCCESS</b>
>
> <b>축하합니다!</b> 🎉 AWS 클라우드에서 Physical AI 강화학습을 처음부터 끝까지 완료했습니다. 약 ₩16,000의 비용으로 4족 보행 로봇이 거친 지형을 걷는 정책을 학습하고, 실제 로봇에 배포할 수 있는 형태로 export했습니다.

---

👈 [Lab 6: Play 모드 & Policy Export](06-play-mode.md)
👉 [Appendix A: 실전 트러블슈팅 12선](appendix-a-troubleshooting.md)

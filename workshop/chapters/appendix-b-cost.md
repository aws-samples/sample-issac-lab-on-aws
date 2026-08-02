# Appendix B: 비용 분석 & 최적화

---

## 이번 워크샵 실제 비용

```
인스턴스: g6e.4xlarge, ap-northeast-2 (Seoul)
온디맨드 요금: ~$3.00/hr

세부 내역:
  환경 셋업 + 디버깅    ~2.0시간  = $6.00
  Docker 빌드           ~0.5시간  = $1.50
  RL 훈련               ~1.25시간 = $3.75
  Play 모드             ~0.2시간  = $0.60
  ─────────────────────────────────
  EC2 합계              ~4.0시간  ≈ $11.85

EBS 저장소:
  300 GB gp3 (root):    ~$0.03/hr
  500 GB gp3 (data):    ~$0.05/hr
  합계                  ~$0.08/hr × 4hr ≈ $0.32

총 비용: ~$12.17 (₩17,000)
```

---

## 인스턴스별 비용 비교

| 인스턴스 | GPU | VRAM | 온디맨드/hr | Spot/hr | 용도 |
|----------|-----|------|------------|---------|------|
| g6e.xlarge | 1× L40S | 48 GB | ~$1.00 | ~$0.35 | 개발/디버깅 |
| <b>g6e.4xlarge</b> | <b>1× L40S</b> | <b>48 GB</b> | <b>~$3.00</b> | <b>~$1.00</b> | <b>표준 훈련</b> |
| g6e.12xlarge | 4× L40S | 192 GB | ~$8.00 | ~$2.80 | 대규모 훈련 |
| g6e.48xlarge | 8× L40S | 384 GB | ~$32.00 | ~$11.00 | 분산 훈련 |

> 가격은 ap-northeast-2 (Seoul) 기준 근사치입니다.

---

## 비용 최적화 전략

### 1. Spot 인스턴스 (~60-70% 할인)

```hcl
resource "aws_spot_instance_request" "isaac" {
  ami                    = data.aws_ami.dl_base.id
  instance_type          = "g6e.4xlarge"
  spot_price             = "1.50"  # 최대 지불 가격
  wait_for_fulfillment   = true

  # Spot 중단 시 체크포인트에서 재개 가능
}
```

> ℹ️ <b>INFO</b>
>
> RL 훈련은 50 iteration마다 체크포인트를 저장하므로, Spot 중단 시 `--resume` 플래그로 이어서 학습할 수 있습니다. <b>중단 허용 워크로드에 최적.</b>

### 2. GPU 유휴 자동 중지

이번 워크샵에서 사용한 CloudWatch 알람:

```
GPU 사용률 < 5%가 30분 지속 → EC2 자동 Stop
```

훈련 완료 후 SSH 세션을 열어두고 퇴근해도 자동으로 과금이 중지됩니다.

### 3. 인스턴스 크기 최적화

```
개발/디버깅:    g6e.xlarge    ($1/hr)   ← num_envs=256
표준 훈련:      g6e.4xlarge   ($3/hr)   ← num_envs=4096
대규모 훈련:    g6e.12xlarge  ($8/hr)   ← num_envs=16384
```

### 4. EBS 스냅샷

사용하지 않을 때 EBS를 스냅샷으로 저장하면 ~60% 비용 절약:

```bash
# 스냅샷 생성
aws ec2 create-snapshot --volume-id vol-xxx --description "isaac-data"

# 스냅샷에서 복원
aws ec2 create-volume --snapshot-id snap-xxx --availability-zone ap-northeast-2a
```

### 5. 리전 선택

| 리전 | g6e.4xlarge/hr | 비고 |
|------|---------------|------|
| us-east-1 (Virginia) | ~$1.32 | <b>가장 저렴</b> |
| us-west-2 (Oregon) | ~$1.32 | 저렴 |
| ap-northeast-2 (Seoul) | ~$3.00 | 한국 접속 빠름 |
| eu-west-1 (Ireland) | ~$1.50 | 유럽 |

> ℹ️ <b>INFO</b>
>
> 네트워크 지연이 중요하지 않은 headless 훈련은 <b>us-east-1</b>에서 실행하면 비용을 ~56% 절약할 수 있습니다.

---

## 비용 시나리오별 비교

| 시나리오 | 설정 | 예상 비용 |
|---------|------|----------|
| 이번 워크샵 (그대로) | g6e.4xlarge, Seoul, On-Demand | <b>~$12</b> |
| 비용 최적화 | g6e.4xlarge, Virginia, Spot | <b>~$2.50</b> |
| 큰 모델 학습 | g6e.12xlarge, Virginia, Spot | <b>~$8</b> |
| 분산 훈련 (8 GPU) | g6e.48xlarge, Virginia, Spot | <b>~$35</b> |

---

👈 [Appendix A: 실전 트러블슈팅 12선](appendix-a-troubleshooting.md)
👉 [Appendix C: 소프트웨어 버전 & 참고자료](appendix-c-references.md)

# Lab 4: 강화학습 훈련 실행

> ℹ️ <b>INFO</b>
>
> <b>소요 시간</b>: 약 75분 (훈련 대기)
> <b>목표</b>: PPO 알고리즘으로 ANYmal-C의 rough terrain 보행 정책을 학습합니다.

---

## 4.1 훈련 실행

### 캐시 디렉토리 준비

```bash
# Isaac Sim 셰이더 캐시 — 첫 실행 시 4분 컴파일을 이후 실행에서 건너뜀
ISAAC_SIM_CACHE="/scratch/isaac-sim-cache"
mkdir -p "$ISAAC_SIM_CACHE"/{kit,ov,pip,glcache,computecache}
mkdir -p /data/{logs,checkpoints}
```

### 훈련 시작

```bash
docker run --rm --gpus all --network=host \
  --entrypoint /workspace/isaaclab/isaaclab.sh \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  -v "$ISAAC_SIM_CACHE/kit:/isaac-sim/kit/cache:rw" \
  -v "$ISAAC_SIM_CACHE/ov:/root/.cache/ov:rw" \
  -v "$ISAAC_SIM_CACHE/pip:/root/.cache/pip:rw" \
  -v "$ISAAC_SIM_CACHE/glcache:/root/.cache/nvidia/GLCache:rw" \
  -v "$ISAAC_SIM_CACHE/computecache:/root/.nv/ComputeCache:rw" \
  -v "/data/checkpoints:/workspace/isaaclab/logs:rw" \
  isaac-lab-ready:latest \
  -p scripts/reinforcement_learning/rsl_rl/train.py \
    --task Isaac-Velocity-Rough-Anymal-C-v0 \
    --headless
```

> ⚠️ <b>WARNING</b>
>
> <b>각 인자의 의미:</b>
> - `--entrypoint /workspace/isaaclab/isaaclab.sh` — 스트리밍 모드 대신 훈련 모드
> - `-p` — isaaclab.sh에게 Python 스크립트 실행을 지시
> - `--task` — 환경 이름 (Anymal-C + Rough Terrain)
> - `--headless` — 모니터 없이 실행 (GPU 렌더링만, 화면 출력 없음)

### 볼륨 마운트 설명

| 마운트 | 용도 |
|--------|------|
| `kit/cache` | 셰이더 캐시 — 첫 실행 4분 컴파일 방지 |
| `.cache/ov` | Omniverse 에셋 캐시 |
| `.cache/pip` | pip 패키지 캐시 |
| `GLCache` | OpenGL 셰이더 캐시 |
| `ComputeCache` | CUDA 컴퓨트 캐시 |
| `/workspace/isaaclab/logs` | <b>체크포인트 저장 위치</b> |

> 🚨 <b>DANGER</b>
>
> <b>소스 마운트 금지</b>: `-v "/opt/isaaclab/source:/workspace/isaaclab/source:rw"`를 하지 마세요. editable install(`pip install -e`)의 `.pth` 참조가 깨져서 `ModuleNotFoundError`가 발생합니다.

---

## 4.2 훈련 초기 로그 이해

처음 4분간은 셰이더 컴파일로 아무 출력이 없습니다. 이후:

```
[INFO] Loading experiment from directory: logs/rsl_rl/anymal_c_rough
[INFO] environment: Isaac-Velocity-Rough-Anymal-C-v0
[INFO] number of environments: 4096
[INFO] number of observations: 48
[INFO] number of actions: 12

Learning iteration 0/1500
  Mean reward:            -0.50
  Mean episode length:    13.60
  Value function loss:    4.203
  Surrogate loss:         0.023
  Collection time:        1.234 s
  Learning time:          0.567 s
```

### 로그 항목 설명

| 항목 | 의미 |
|------|------|
| environments: 4096 | GPU에서 동시에 4096개 로봇 시뮬레이션 |
| observations: 48 | 각 로봇이 감지하는 센서 값 48개 |
| actions: 12 | 각 로봇의 12개 관절 토크 |
| Mean reward | 전체 환경의 평균 보상 (양수 = 잘 학습 중) |
| Mean episode length | 로봇이 넘어지기까지의 평균 스텝 수 |

---

## 4.3 PPO 하이퍼파라미터

이번 훈련에 사용된 실제 설정입니다:

```yaml
# agent.yaml (자동 생성됨)
algorithm:
  class_name: PPO
  num_learning_epochs: 5        # 수집 데이터로 5번 반복 학습
  num_mini_batches: 4           # 데이터를 4개 미니배치로 분할
  learning_rate: 0.001          # 초기 학습률
  gamma: 0.99                   # 미래 보상 할인율 (장기 보상 중시)
  lam: 0.95                     # GAE lambda (분산-편향 균형)
  entropy_coef: 0.005           # 탐색 유도 계수
  desired_kl: 0.01              # 정책 업데이트 제한

policy:
  class_name: ActorCritic
  init_noise_std: 1.0           # 초기 탐색 노이즈 (→ 학습 중 0.39로 감소)
  actor_hidden_dims: [512, 256, 128]
  critic_hidden_dims: [512, 256, 128]
  activation: elu
```

---

## 4.4 보상 함수 구조

로봇의 행동을 평가하는 <b>보상 함수</b>가 학습의 핵심입니다:

### 양의 보상 (잘 하면 +)

```python
track_lin_vel_xy_exp    # 명령 직선 속도를 정확히 따라가면 +
track_ang_vel_z_exp     # 명령 회전 속도를 정확히 따라가면 +
```

### 음의 보상 = 패널티 (나쁘면 -)

```python
lin_vel_z_l2            # 수직 방향 속도 — 튀면 패널티
ang_vel_xy_l2           # 롤/피치 각속도 — 흔들리면 패널티
dof_torques_l2          # 관절 토크 — 에너지 낭비 패널티
dof_acc_l2              # 관절 가속도 — 급격한 움직임 패널티
action_rate_l2          # 행동 변화율 — 떨림 패널티
feet_air_time           # 발 공중 시간 — 걸음걸이 리듬 유도
undesired_contacts      # 무릎/몸통이 바닥에 닿으면 패널티
```

> <b>핵심</b>: 보상 함수 설계가 로봇의 최종 행동을 결정합니다. 속도 추적만 보상하면 에너지를 과다 사용하고, 에너지 패널티만 주면 움직이지 않습니다. 이 균형을 맞추는 것이 <b>reward engineering</b>입니다.

---

## 4.5 커리큘럼 학습

Isaac Lab은 <b>커리큘럼 학습</b>을 자동으로 수행합니다:

```
Level 0: 평평한 바닥              → 걷기 기초 학습
Level 1-2: 약간의 요철            → 균형 유지 학습
Level 3-4: 경사면 + 바위          → 적응적 보행 학습
Level 5-6: 계단 + 심한 경사       → 고급 지형 대응
```

- 현재 레벨 성공률 높으면 → 다음 레벨로 <b>승격</b>
- 실패율 높으면 → 이전 레벨로 <b>강등</b>

최종 Terrain Level이 높을수록 로봇이 더 어려운 지형을 다룰 수 있습니다.

---

## 4.6 훈련 모니터링

### GPU 사용률 확인

```bash
# 다른 터미널에서
watch -n 5 nvidia-smi
```

정상 상태:
```
GPU Util: 68-84%
Memory:   10.4 GB / 48 GB
```

### 체크포인트 확인

```bash
# 50 iteration마다 자동 저장
ls -la /data/checkpoints/rsl_rl/anymal_c_rough/*/model_*.pt
```

### S3 동기화

```bash
# 30분마다 자동 실행 (cron)
# 수동 실행:
sync-checkpoints
```

---

## 4.7 예상 학습 곡선

```
Phase 1: 탐색기 (iter 0-40)
  Reward: -0.5 → -4.9 ▼ (정상! 패널티 항목이 활성화)
  Episode: 13 → 100

Phase 2: 기초 학습 (iter 40-120)
  Reward: -4.9 → +5.0 ▲ (보상이 0을 돌파 = 의미 있는 보행 시작)
  Episode: 100 → 400

Phase 3: 정교화 (iter 120-300)
  Reward: +5.0 → +15.0 ▲ (안정적 보행, 속도 추적 향상)
  Episode: 400 → 900

Phase 4: 수렴 (iter 300-1500)
  Reward: +15.0 → +16.3 ▶ (수렴 중, 지형 난이도만 상승)
  Terrain Level: 3 → 5.9
```

> ✅ <b>SUCCESS</b>
>
> <b>성공 기준</b>: 최종 Mean Reward > +10, Episode Length > 500이면 로봇이 안정적으로 보행하는 것입니다.

---

## 4.8 훈련 완료 확인

```bash
# 최종 체크포인트 확인
ls -lh /data/checkpoints/rsl_rl/anymal_c_rough/*/model_1499.pt

# 체크포인트 수 확인
ls /data/checkpoints/rsl_rl/anymal_c_rough/*/*.pt | wc -l
# 31개 (model_0.pt ~ model_1499.pt, 50 간격)

# TensorBoard 이벤트 파일
ls -lh /data/checkpoints/rsl_rl/anymal_c_rough/*/events.out.tfevents.*
# ~2.6 MB
```

---

## 체크포인트

- [ ] 훈련이 1500 iteration 완료
- [ ] `model_1499.pt` 체크포인트 파일 존재
- [ ] 최종 Mean Reward > +10
- [ ] 최종 Episode Length > 500
- [ ] GPU 사용률이 정상 범위 (60-85%)

---

👈 [Lab 3: Isaac Lab Docker 이미지 빌드](03-docker-build.md)
👉 [Lab 5: 학습 결과 분석](05-results.md)

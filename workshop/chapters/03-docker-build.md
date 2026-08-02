# Lab 3: Isaac Lab Docker 이미지 빌드

> ℹ️ <b>INFO</b>
>
> <b>소요 시간</b>: 약 30분 (빌드 대기 포함)
> <b>목표</b>: Isaac Sim + Isaac Lab Docker 이미지를 빌드하고, 핵심 패키지 누락 문제를 해결합니다.

---

## 3.1 Isaac Sim vs Isaac Lab

```
Isaac Sim                           Isaac Lab
━━━━━━━━━━━━━━━━━━━               ━━━━━━━━━━━━━━━━━━━
물리 시뮬레이션 엔진                  RL 프레임워크
PhysX 5, Vulkan 렌더러               사전 정의 환경, 보상 함수
NGC에 공식 Docker 이미지 있음          NGC에 이미지 없음 ⚠️
nvcr.io/nvidia/isaac-sim:4.5.0      소스에서 직접 빌드 필요
```

> 🚨 <b>DANGER</b>
>
> <b>핵심 주의점</b>: Isaac Lab은 NGC에 pre-built Docker 이미지를 <b>제공하지 않습니다</b>. 소스에서 직접 빌드해야 합니다.

---

## 3.2 3단계 빌드 프로세스

### Step 1: Isaac Sim 이미지 Pull

```bash
# NGC 로그인
echo "$NGC_API_KEY" | docker login nvcr.io --username '$oauthtoken' --password-stdin

# Isaac Sim 이미지 다운로드 (~22.6 GB, ~5분)
docker pull nvcr.io/nvidia/isaac-sim:4.5.0
```

### Step 2: Isaac Lab 소스 빌드

```bash
# Isaac Lab 소스 클론
git clone --depth 1 --branch v2.1.0 \
  https://github.com/isaac-sim/IsaacLab.git /opt/isaaclab
cd /opt/isaaclab

# Docker 이미지 빌드 (~10-15분)
docker compose --profile base build

# 결과: isaac-lab-base:latest (~25 GB)
docker images | grep isaac-lab
```

### Step 3: 코어 패키지 수동 설치 (★ 가장 중요)

> 🚨 <b>DANGER</b>
>
> <b>이 단계를 건너뛰면 훈련이 100% 실패합니다.</b>
> 
> `docker compose --profile base build`는 extension 패키지(isaaclab\_tasks, isaaclab\_rl 등)만 설치하고, <b>코어 `isaaclab` 패키지는 설치하지 않습니다</b>. 이것은 공식 문서에 명확히 언급되지 않는 함정입니다.

```bash
# 컨테이너를 시작하고 코어 패키지 설치
docker run --name isaac-lab-setup --gpus all \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  --entrypoint bash isaac-lab-base:latest -c '
    # ★ 핵심: --no-build-isolation 플래그 필수
    /workspace/isaaclab/_isaac_sim/python.sh -m pip install \
      --no-build-isolation -e /workspace/isaaclab/source/isaaclab

    # RL 프레임워크 설치 (RSL-RL)
    cd /workspace/isaaclab && ./isaaclab.sh -i rsl_rl

    # 설치 검증
    /workspace/isaaclab/_isaac_sim/python.sh -c \
      "import isaaclab; print(f\"isaaclab installed: {isaaclab.__file__}\")"
  '

# 설치된 상태를 새 이미지로 커밋
docker commit isaac-lab-setup isaac-lab-ready:latest
docker rm isaac-lab-setup

# 최종 이미지 확인
docker images | grep isaac-lab-ready
# isaac-lab-ready:latest   ~26.8 GB
```

### 왜 `--no-build-isolation`인가?

```
일반 pip install                    --no-build-isolation
━━━━━━━━━━━━━━━                    ━━━━━━━━━━━━━━━━━━━
격리된 빌드 환경 생성                  현재 환경에서 직접 빌드
setuptools 별도 설치 필요              기존 setuptools 사용
→ flatdict 의존성 → pkg_resources     → 문제 없음 ✅
→ ModuleNotFoundError 발생 ❌
```

Isaac Sim의 Python 환경은 특수한 구조(`_isaac_sim/python.sh`)를 사용하므로, pip의 기본 빌드 격리가 setuptools를 찾지 못합니다.

---

## 3.3 빌드 결과 검증

```bash
# 최종 이미지로 검증
docker run --rm --gpus all \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  --entrypoint bash isaac-lab-ready:latest -c '
    echo "=== Python 경로 ==="
    /workspace/isaaclab/_isaac_sim/python.sh -c "import sys; print(sys.executable)"

    echo "=== 코어 패키지 ==="
    /workspace/isaaclab/_isaac_sim/python.sh -c "import isaaclab; print(isaaclab.__file__)"

    echo "=== Extension 패키지 ==="
    /workspace/isaaclab/_isaac_sim/python.sh -c "import isaaclab_tasks; print(isaaclab_tasks.__file__)"

    echo "=== RSL-RL ==="
    /workspace/isaaclab/_isaac_sim/python.sh -c "import rsl_rl; print(rsl_rl.__file__)"

    echo "=== 사용 가능한 환경 목록 ==="
    /workspace/isaaclab/_isaac_sim/python.sh -c "
import isaaclab_tasks
import gymnasium as gym
envs = [e for e in gym.envs.registry if \"Isaac\" in e]
print(f\"총 {len(envs)}개 Isaac 환경 사용 가능\")
for e in sorted(envs)[:10]:
    print(f\"  {e}\")
print(\"  ...\")
"
  '
```

예상 출력:
```
=== 코어 패키지 ===
/workspace/isaaclab/source/isaaclab/isaaclab/__init__.py
=== Extension 패키지 ===
/workspace/isaaclab/source/isaaclab_tasks/isaaclab_tasks/__init__.py
=== RSL-RL ===
/workspace/isaaclab/_isaac_sim/kit/python/lib/python3.10/site-packages/rsl_rl/__init__.py
=== 사용 가능한 환경 목록 ===
총 XX개 Isaac 환경 사용 가능
  Isaac-Velocity-Flat-Anymal-C-v0
  Isaac-Velocity-Rough-Anymal-C-v0
  ...
```

---

## 3.4 Docker 이미지 구조 이해

```
isaac-lab-ready:latest (26.8 GB)
├── /isaac-sim/                    ← Isaac Sim 4.5.0
│   ├── kit/                       ← Kit 엔진 (Omniverse 기반)
│   │   ├── cache/                 ← 셰이더 캐시 (볼륨 마운트 대상)
│   │   └── python/                ← Python 3.10 + PyTorch 2.5.1
│   ├── exts/                      ← Omniverse extensions
│   └── runheadless.sh             ← 기본 ENTRYPOINT (스트리밍 모드)
│
├── /workspace/isaaclab/           ← Isaac Lab v2.1.0
│   ├── isaaclab.sh                ← ★ 훈련 시 사용할 진입점
│   ├── source/
│   │   ├── isaaclab/              ← 코어 패키지 (Step 3에서 설치)
│   │   ├── isaaclab_tasks/        ← 환경 정의 (Anymal, Humanoid 등)
│   │   └── isaaclab_rl/           ← RL wrapper
│   └── scripts/
│       └── reinforcement_learning/
│           └── rsl_rl/
│               ├── train.py       ← 훈련 스크립트
│               └── play.py        ← 추론/시각화 스크립트
```

> ⚠️ <b>WARNING</b>
>
> <b>ENTRYPOINT 주의</b>: 이미지의 기본 ENTRYPOINT는 `runheadless.sh`로, Isaac Sim을 <b>스트리밍 서버 모드</b>로 시작합니다. 훈련 시에는 반드시 `--entrypoint /workspace/isaaclab/isaaclab.sh`로 오버라이드해야 합니다.

---

## 3.5 EULA 동의

Isaac Sim은 NVIDIA EULA 동의가 필요합니다:

```bash
# Docker 환경변수로 전달 (권장)
-e "ACCEPT_EULA=Y"
-e "PRIVACY_CONSENT=Y"
```

이 환경변수가 없으면 시뮬레이션이 시작되지 않습니다.

---

## 체크포인트

- [ ] `docker images`에 `isaac-lab-ready:latest` (~26.8 GB) 확인
- [ ] `import isaaclab` 성공 확인
- [ ] `import isaaclab_tasks` 성공 확인
- [ ] `import rsl_rl` 성공 확인
- [ ] ENTRYPOINT 오버라이드 필요성 이해

---

👈 [Lab 2: AWS GPU 인프라 구축](02-infrastructure.md)
👉 [Lab 4: 강화학습 훈련 실행](04-training.md)

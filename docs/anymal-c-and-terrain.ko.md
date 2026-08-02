# ANYmal-C 선정 이유 & Rough Terrain 구성

> Q&A 형식 노트. Physical AI 워크샵의 로봇/환경 설계 결정 근거와 확장 방법 정리.
> 영문판: [`anymal-c-and-terrain.md`](./anymal-c-and-terrain.md)

---

## 1. 왜 ANYmal-C인가?

`workshop/chapters/01-concepts.md:83-90`에 명시된 근거:

- **산업 표준 벤치마크**: 스위스 ANYbotics社의 상용 4족 로봇 (50 kg, 12관절). 실제 산업시설 자율 점검에 배포된 검증된 플랫폼.
- **Isaac Lab의 기본 등록 환경**: `Isaac-Velocity-Rough-Anymal-C-v0`가 `isaaclab_tasks` extension에 사전 등록되어 있음 (`workshop/chapters/03-docker-build.md:146`). 별도 URDF/USD 준비 없이 turnkey로 학습 가능.
- **12관절 대칭 구조**: 다리 4개 × 3관절 (HAA/HFE/KFE) 의 규칙적 구조 → RL 정책 학습이 안정적, 학계 재현성 확보.

### 스펙 요약

| 항목 | 값 |
|---|---|
| 무게 | ~50 kg |
| 관절 수 | 12개 (다리 4개 × 3관절) |
| 센서 | IMU, 관절 인코더, LiDAR, 카메라 |
| 용도 | 산업시설 자율 점검, 위험 지역 탐사 |
| 제조사 | ANYbotics (스위스) |

---

## 2. Terrain 생성 도구 & 구성 단계

### 도구

Isaac Lab의 **`TerrainGenerator`** (procedural mesh 기반). PhysX 5의 tri-mesh collider로 렌더링됩니다.

### 구성 단계 — 워크샵에서 명시적으로 설정하지 않음

다음 경로로 자동 로드됩니다:

```
Lab 3 (Docker build)
  └─ isaaclab_tasks extension 설치
      └─ Isaac-Velocity-Rough-Anymal-C-v0 태스크 등록
          └─ AnymalCRoughEnvCfg 내부에 TerrainImporterCfg 포함
              └─ sub_terrains: pyramid_stairs, random_rough, sloped, discrete_obstacles ...
```

**설정 파일 위치**: `isaaclab_tasks/manager_based/locomotion/velocity/config/rough_env_cfg.py` (Docker 컨테이너 내부).

### 커리큘럼 학습 레벨 매핑

각 sub_terrain의 `difficulty_range` 파라미터가 다음 레벨로 매핑됩니다 (`workshop/chapters/04-training.md:154-157`):

```
Level 0: 평평한 바닥              → 걷기 기초 학습
Level 1-2: 약간의 요철            → 균형 유지 학습
Level 3-4: 경사면 + 바위          → 적응적 보행 학습
Level 5-6: 계단 + 심한 경사       → 고급 지형 대응
```

- 현재 레벨 성공률 높으면 → 다음 레벨로 **승격**
- 실패율 높으면 → 이전 레벨로 **강등**

---

## 3. 다른 지형으로 일반화 가능한가?

**예 — 세 층위에서 확장 가능합니다.**

### 낮은 층위 — task 스왑

`--task` 인자만 변경하면 됩니다. `workshop/chapters/07-cleanup.md:77-84`에서 명시적으로 안내:

```bash
# 평지 (동일 로봇)
--task Isaac-Velocity-Flat-Anymal-C-v0

# 다른 로봇 (동일 지형)
--task Isaac-Velocity-Rough-Unitree-Go2-v0
--task Isaac-Velocity-Rough-H1-v0

# 로봇 팔 (매니퓰레이션)
--task Isaac-Lift-Cube-Franka-v0
```

### 중간 층위 — sub_terrain 조합 변경

`TerrainImporterCfg.terrain_generator.sub_terrains` 딕셔너리에 프리미티브를 추가/조합. Isaac Lab이 제공하는 프리미티브:

| 프리미티브 | 설명 |
|---|---|
| `HfPyramidSlopedTerrainCfg` | 피라미드형 경사면 |
| `HfDiscreteObstaclesTerrainCfg` | 이산 장애물 |
| `MeshPyramidStairsTerrainCfg` | 계단 |
| `MeshGapTerrainCfg` | 갭(구멍) |
| `HfWaveTerrainCfg` | 파형 지형 |

각 프리미티브는 `difficulty ∈ [0,1]` 파라미터로 자동 스케일됩니다.

### 높은 층위 — 커스텀 지형

`SubTerrainBaseCfg`를 상속해 임의 heightfield/mesh 함수 작성 → 커리큘럼과 자동 통합.

> **Sim-to-real 주의**: 지형의 마찰계수·거칠기 파라미터를 domain randomization에 포함해야 실제 지형 이관 시 성능이 유지됩니다.

---

## 4. 제약 사항

- 지형이 바뀌어도 observation space는 그대로 (proprioception 48차원).
- 단, **height scan 센서**를 붙이는 순간 obs 차원이 변해 정책 네트워크 재설계가 필요.
- 커리큘럼 임계값(승격/강등 성공률)도 지형 특성에 맞게 재튜닝 권장.

---

## 참고

- `workshop/chapters/01-concepts.md` — ANYmal-C 소개
- `workshop/chapters/04-training.md` — 훈련 파이프라인 & 커리큘럼
- `workshop/chapters/07-cleanup.md` — 다른 태스크 스왑 예시
- [Isaac Lab TerrainGenerator 공식 문서](https://isaac-sim.github.io/IsaacLab/main/source/api/lab/isaaclab.terrains.html)

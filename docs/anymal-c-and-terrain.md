# ANYmal-C Selection & Rough Terrain Configuration

> Q&A-style notes documenting the robot/environment design decisions in the Physical AI workshop and how to extend them.
> Korean version: [`anymal-c-and-terrain.ko.md`](./anymal-c-and-terrain.ko.md)

---

## 1. Why ANYmal-C?

Rationale from `workshop/chapters/01-concepts.md:83-90`:

- **Industry-standard benchmark**: Commercial quadruped robot from Swiss company ANYbotics (50 kg, 12 joints). A validated platform actually deployed for industrial facility inspection.
- **Pre-registered environment in Isaac Lab**: `Isaac-Velocity-Rough-Anymal-C-v0` ships pre-registered inside the `isaaclab_tasks` extension (`workshop/chapters/03-docker-build.md:146`). Turnkey training with no need to prepare URDF/USD assets.
- **Symmetric 12-joint structure**: Regular kinematics of 4 legs × 3 joints (HAA/HFE/KFE) → stable RL policy learning and strong academic reproducibility.

### Spec Summary

| Item | Value |
|---|---|
| Weight | ~50 kg |
| Joints | 12 (4 legs × 3 joints) |
| Sensors | IMU, joint encoders, LiDAR, cameras |
| Use case | Autonomous industrial inspection, hazardous-area exploration |
| Manufacturer | ANYbotics (Switzerland) |

---

## 2. Terrain Generation Tool & Configuration Step

### Tool

Isaac Lab's built-in **`TerrainGenerator`** (procedural, mesh-based). Rendered as tri-mesh colliders by PhysX 5.

### Configuration step — not set explicitly in the workshop

The terrain is loaded automatically along this path:

```
Lab 3 (Docker build)
  └─ isaaclab_tasks extension installed
      └─ Isaac-Velocity-Rough-Anymal-C-v0 task registered
          └─ AnymalCRoughEnvCfg embeds a TerrainImporterCfg
              └─ sub_terrains: pyramid_stairs, random_rough, sloped, discrete_obstacles ...
```

**Config file location**: `isaaclab_tasks/manager_based/locomotion/velocity/config/rough_env_cfg.py` (inside the Docker container).

### Curriculum Learning Level Mapping

Each sub_terrain's `difficulty_range` parameter maps to the following levels (`workshop/chapters/04-training.md:154-157`):

```
Level 0: Flat ground              → learn basic walking
Level 1-2: Slight roughness       → learn balance
Level 3-4: Slopes + rocks         → learn adaptive gait
Level 5-6: Stairs + steep slopes  → advanced terrain handling
```

- High success rate at current level → **promoted** to next level
- High failure rate → **demoted** to previous level

---

## 3. Is It Generalizable to Other Terrains?

**Yes — extensible at three levels.**

### Low level — task swap

Only the `--task` argument needs to change. Explicitly documented in `workshop/chapters/07-cleanup.md:77-84`:

```bash
# Flat ground (same robot)
--task Isaac-Velocity-Flat-Anymal-C-v0

# Different robot (same terrain)
--task Isaac-Velocity-Rough-Unitree-Go2-v0
--task Isaac-Velocity-Rough-H1-v0

# Robot arm (manipulation)
--task Isaac-Lift-Cube-Franka-v0
```

### Mid level — modify sub_terrain composition

Add or combine primitives in `TerrainImporterCfg.terrain_generator.sub_terrains`. Primitives shipped with Isaac Lab:

| Primitive | Description |
|---|---|
| `HfPyramidSlopedTerrainCfg` | Pyramid-shaped slope |
| `HfDiscreteObstaclesTerrainCfg` | Discrete obstacles |
| `MeshPyramidStairsTerrainCfg` | Stairs |
| `MeshGapTerrainCfg` | Gaps (holes) |
| `HfWaveTerrainCfg` | Wave-shaped terrain |

Each primitive auto-scales via a `difficulty ∈ [0,1]` parameter.

### High level — custom terrain

Subclass `SubTerrainBaseCfg` and write an arbitrary heightfield/mesh function → automatically integrated with the curriculum.

> **Sim-to-real caveat**: Terrain friction and roughness parameters must be included in domain randomization to preserve performance when transferring to real-world surfaces.

---

## 4. Constraints

- Observation space stays the same when terrain changes (48-dim proprioception).
- However, **adding a height-scan sensor** changes the observation dimension → the policy network must be redesigned.
- Curriculum promotion/demotion thresholds should also be retuned to match new terrain characteristics.

---

## References

- `workshop/chapters/01-concepts.md` — ANYmal-C introduction
- `workshop/chapters/04-training.md` — Training pipeline & curriculum
- `workshop/chapters/07-cleanup.md` — Task swap examples
- [Isaac Lab TerrainGenerator official docs](https://isaac-sim.github.io/IsaacLab/main/source/api/lab/isaaclab.terrains.html)

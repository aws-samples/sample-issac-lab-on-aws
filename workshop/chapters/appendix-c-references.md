# Appendix C: 소프트웨어 버전 & 참고자료

---

## 소프트웨어 버전

| 소프트웨어 | 버전 | 비고 |
|-----------|------|------|
| Ubuntu | 22.04 LTS | DL Base OSS AMI |
| NVIDIA Driver | 580.126.09 | AMI 포함 |
| CUDA | 13.0 | AMI 포함 |
| Docker | 27.x | AMI 포함 |
| NVIDIA Container Toolkit | latest | AMI 포함 |
| Isaac Sim | <b>4.5.0</b> | NGC 컨테이너 |
| Isaac Lab | <b>v2.1.0</b> | 소스 빌드 |
| PyTorch | 2.5.1 | Isaac Sim 내장 |
| RSL-RL | 2.x | isaaclab.sh -i rsl_rl |
| Python | 3.10 | Isaac Sim 내장 |
| Terraform | 1.5+ | 로컬 설치 |
| AWS Provider | 5.0+ | Terraform 프로바이더 |

---

## AWS 리소스 사양

| 리소스 | 사양 |
|--------|------|
| <b>EC2 Instance</b> | g6e.4xlarge |
| GPU | NVIDIA L40S (48 GB VRAM) |
| CPU | AMD EPYC 7R13 (16 vCPU) |
| RAM | 128 GiB |
| Root EBS | 300 GB gp3 (6000 IOPS, 500 MB/s) |
| Data EBS | 500 GB gp3 |
| Instance Store | NVMe (AMI가 LVM으로 /opt/dlami/nvme에 마운트) |
| AMI | Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04) |

---

## 훈련 하이퍼파라미터

```yaml
# 환경
task: Isaac-Velocity-Rough-Anymal-C-v0
num_envs: 4096
max_iterations: 1500

# PPO
num_learning_epochs: 5
num_mini_batches: 4
learning_rate: 0.001
gamma: 0.99
lam: 0.95
entropy_coef: 0.005
desired_kl: 0.01

# 정책 네트워크
actor_hidden_dims: [512, 256, 128]
critic_hidden_dims: [512, 256, 128]
activation: elu
init_noise_std: 1.0
```

---

## 훈련 결과 수치

| 지표 | 초기 | 최종 |
|------|------|------|
| Mean Reward | -0.50 | +16.29 |
| Episode Length | 13.6 | 897 |
| Track Lin Vel XY | 0.004 | 0.785 |
| Track Ang Vel Z | 0.002 | 0.400 |
| Terrain Level | 3.53 | 5.90 |
| Policy Noise Std | 0.997 | 0.393 |
| Throughput (fps) | 19,537 | 33,014 |
| VRAM Usage | - | 10.4 GB |
| Training Time | - | 75 min |
| Total Timesteps | - | 147,456,000 |

---

## 산출물 목록

| 파일 | 크기 | 용도 |
|------|------|------|
| `model_1499.pt` | 6.6 MB | 최종 학습 체크포인트 |
| `policy.pt` | 1.2 MB | TorchScript JIT (C++ 추론) |
| `policy.onnx` | 1.1 MB | ONNX (TensorRT/Jetson 추론) |
| `anymal_c_play_30s.mp4` | 2.8 MB | 보행 시각화 비디오 (30초) |
| `events.out.tfevents.*` | 2.6 MB | TensorBoard 학습 로그 |
| `agent.yaml` | - | PPO 하이퍼파라미터 |
| `env.yaml` | - | 환경 설정 |

---

## 참고 문헌

### 공식 문서

- [Isaac Lab Documentation](https://isaac-sim.github.io/IsaacLab/)
- [Isaac Sim Documentation](https://docs.omniverse.nvidia.com/isaacsim/)
- [NVIDIA NGC Catalog — Isaac Sim](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/isaac-sim)
- [AWS EC2 G6e Instances](https://aws.amazon.com/ec2/instance-types/g6e/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)

### 논문

- Schulman, J. et al. (2017). *Proximal Policy Optimization Algorithms*. arXiv:1707.06347
- Hwangbo, J. et al. (2019). *Learning agile and dynamic motor skills for legged robots*. Science Robotics, 4(26)
- Rudin, N. et al. (2022). *Learning to Walk in Minutes Using Massively Parallel Deep Reinforcement Learning*. CoRL 2021
- Miki, T. et al. (2022). *Learning robust perceptive locomotion for quadrupedal robots in the wild*. Science Robotics, 7(62)

### 관련 프로젝트

- [RSL-RL](https://github.com/leggedrobotics/rsl_rl) — ETH Zurich의 로봇 학습 RL 라이브러리
- [Legged Gym](https://github.com/leggedrobotics/legged_gym) — Isaac Gym 기반 보행 로봇 학습
- [OmniIsaacGymEnvs](https://github.com/NVIDIA-Omniverse/OmniIsaacGymEnvs) — NVIDIA 공식 RL 환경

---

## 용어 사전

| 용어 | 설명 |
|------|------|
| <b>PPO</b> | Proximal Policy Optimization — 안정적인 정책 경사 RL 알고리즘 |
| <b>Actor-Critic</b> | 정책(Actor)과 가치함수(Critic) 두 네트워크를 사용하는 RL 구조 |
| <b>Curriculum Learning</b> | 쉬운 → 어려운 순서로 학습 난이도를 조절하는 기법 |
| <b>Domain Randomization</b> | 시뮬레이션 파라미터를 랜덤화하여 sim-to-real gap을 줄이는 기법 |
| <b>Sim-to-Real</b> | 시뮬레이션에서 학습한 정책을 실제 로봇에 전이하는 과정 |
| <b>Headless</b> | 모니터/디스플레이 없이 GPU 연산만 수행하는 실행 모드 |
| <b>NGC</b> | NVIDIA GPU Cloud — GPU 최적화 컨테이너/모델 저장소 |
| <b>EBS</b> | Elastic Block Store — AWS의 블록 스토리지 (가상 하드디스크) |
| <b>Nitro</b> | AWS의 차세대 가상화 아키텍처 (NVMe 디바이스 이름 사용) |
| <b>ONNX</b> | Open Neural Network Exchange — 다양한 프레임워크 간 모델 교환 포맷 |
| <b>JIT</b> | Just-In-Time compilation — PyTorch 모델을 C++에서 실행 가능하게 컴파일 |
| <b>USD</b> | Universal Scene Description — Pixar 개발 3D 장면 기술 포맷 |
| <b>PhysX</b> | NVIDIA의 실시간 물리 시뮬레이션 엔진 |

---

👈 [Appendix B: 비용 분석 & 최적화](appendix-b-cost.md)

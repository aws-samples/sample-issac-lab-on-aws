# Appendix A: 실전 트러블슈팅 12선

> ⚠️ WARNING
>
> 이 목록은 2026년 4월 실제 AWS 배포에서 겪은 문제들입니다. 공식 문서에 없는 실전 함정과 해결법을 담았습니다.

***

## 인프라 (Terraform / EC2)

### 1. dpkg Lock 경합

<table><thead><tr><th width="242.546875"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>user_data.sh</code>에서 <code>apt-get install</code> 실패</td></tr><tr><td>에러</td><td><code>E: Could not get lock /var/lib/dpkg/lock-frontend</code></td></tr><tr><td>원인</td><td>Ubuntu <code>unattended-upgrades</code>가 부팅 직후 dpkg lock 점유</td></tr><tr><td>빈도</td><td>거의 매번 (3/3 시도에서 발생)</td></tr></tbody></table>

```bash
# 해결: user_data.sh 상단에 추가
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true
killall -q apt-get dpkg 2>/dev/null || true
sleep 5

# 모든 apt-get에 timeout 옵션
apt-get install -y -o DPkg::Lock::Timeout=120 ...
```

***

### 2. EBS 디바이스 이름 (Nitro)

<table><thead><tr><th width="241.1171875"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>/dev/xvdf</code> 디바이스가 없음</td></tr><tr><td>원인</td><td>g6e = Nitro 기반 → EBS가 <code>/dev/nvme*n1</code>으로 표시</td></tr><tr><td>해결</td><td>동적 디바이스 탐색 함수 사용</td></tr></tbody></table>

```bash
find_data_device() {
  for dev in /dev/nvme*n1; do
    [ -b "$dev" ] || continue
    # Root, LVM, 이미 마운트된 것 제외
    if lsblk -no MOUNTPOINT "$dev" 2>/dev/null | grep -q "^/$"; then continue; fi
    if lsblk -no MOUNTPOINT "$dev" 2>/dev/null | grep -q .; then continue; fi
    if pvs "$dev" 2>/dev/null | grep -q "$dev"; then continue; fi
    echo "$dev"; return
  done
}
```

***

### 3. DL AMI Instance Store 이미 마운트

<table><thead><tr><th width="229.59375"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>mkfs.ext4 /dev/nvmeXn1</code> → "device is in use"</td></tr><tr><td>원인</td><td>DL Base AMI가 NVMe instance store를 LVM으로 <code>/opt/dlami/nvme</code>에 마운트</td></tr><tr><td>해결</td><td>기존 마운트 재활용</td></tr></tbody></table>

```bash
if mountpoint -q /opt/dlami/nvme 2>/dev/null; then
  mkdir -p /opt/dlami/nvme/scratch
  ln -sfn /opt/dlami/nvme/scratch /scratch
else
  mkfs.ext4 -L scratch "$NVME_DEV"
  mkdir -p /scratch && mount "$NVME_DEV" /scratch
fi
```

***

### 4. Terraform templatefile 충돌

<table><thead><tr><th width="223.2421875"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>terraform apply</code> 시 <code>Invalid reference</code> 에러</td></tr><tr><td>원인</td><td>Bash <code>${VAR:-default}</code>가 Terraform 변수로 해석</td></tr><tr><td>해결</td><td><code>$${VAR:-default}</code>로 이스케이프 (double dollar)</td></tr></tbody></table>

```hcl
# main.tf
user_data = base64encode(templatefile("user_data.sh", {
  ngc_api_key = var.ngc_api_key
  # Bash 변수는 $${HOME} 형태로 자동 이스케이프
}))
```

***

### 5. user\_data 재실행 안 됨

<table><thead><tr><th width="223.76171875"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>user_data.sh</code> 수정 → <code>terraform apply</code> → 변화 없음</td></tr><tr><td>원인</td><td>cloud-init은 첫 부팅에서만 <code>user_data</code> 실행</td></tr><tr><td>해결</td><td>인스턴스 재생성</td></tr></tbody></table>

```bash
terraform taint aws_instance.isaac
terraform apply
```

***

## Docker / Isaac Lab

### 6. Isaac Lab NGC 이미지 없음

<table><thead><tr><th width="219.83203125"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>docker pull nvcr.io/nvidia/isaac-lab:v2.1.0</code> → Not Found</td></tr><tr><td>원인</td><td>Isaac Lab은 NGC에 pre-built 이미지를 제공하지 않음</td></tr><tr><td>해결</td><td>소스에서 빌드</td></tr></tbody></table>

```bash
git clone --branch v2.1.0 https://github.com/isaac-sim/IsaacLab.git
cd IsaacLab && docker compose --profile base build
```

***

### 7. 코어 isaaclab 패키지 누락 ★

<table><thead><tr><th width="210.984375"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>ModuleNotFoundError: No module named 'isaaclab'</code></td></tr><tr><td>원인</td><td>Docker build가 extension만 설치, 코어 패키지 누락</td></tr><tr><td>빈도</td><td>100% 발생 (가장 치명적)</td></tr><tr><td>해결</td><td>수동 설치 후 docker commit</td></tr></tbody></table>

```bash
docker run --name setup --gpus all --entrypoint bash isaac-lab-base:latest -c '
  /workspace/isaaclab/_isaac_sim/python.sh -m pip install \
    --no-build-isolation -e /workspace/isaaclab/source/isaaclab
'
docker commit setup isaac-lab-ready:latest
```

***

### 8. Docker Entrypoint 스트리밍 모드

<table><thead><tr><th width="222.6328125"></th><th></th></tr></thead><tbody><tr><td>증상</td><td>컨테이너 실행 후 훈련 미시작, GPU 유휴</td></tr><tr><td>원인</td><td>기본 ENTRYPOINT <code>runheadless.sh</code> = 스트리밍 서버 모드</td></tr><tr><td>해결</td><td>entrypoint 오버라이드</td></tr></tbody></table>

```bash
docker run ... \
  --entrypoint /workspace/isaaclab/isaaclab.sh \
  isaac-lab-ready:latest \
  -p scripts/.../train.py --headless
```

***

### 9. 훈련 스크립트 경로 변경

<table><thead><tr><th width="223.28515625"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>FileNotFoundError: source/standalone/workflows/rsl_rl/train.py</code></td></tr><tr><td>원인</td><td>v2.1.0에서 경로 변경</td></tr><tr><td>해결</td><td>새 경로 사용</td></tr></tbody></table>

```
구: source/standalone/workflows/rsl_rl/train.py
신: scripts/reinforcement_learning/rsl_rl/train.py
```

***

### 10. setuptools 빌드 격리 문제

<table><thead><tr><th width="231.0703125"></th><th></th></tr></thead><tbody><tr><td>증상</td><td><code>pip install -e source/isaaclab</code> → <code>No module named 'pkg_resources'</code></td></tr><tr><td>원인</td><td>pip 빌드 격리 환경에 setuptools 없음</td></tr><tr><td>해결</td><td><code>--no-build-isolation</code> 플래그</td></tr></tbody></table>

```bash
pip install --no-build-isolation -e /workspace/isaaclab/source/isaaclab
```

***

### 11. Volume Mount가 Editable Install 덮어쓰기

<table><thead><tr><th width="232.42578125"></th><th></th></tr></thead><tbody><tr><td>증상</td><td>패키지 설치 후에도 <code>ModuleNotFoundError</code> 지속</td></tr><tr><td>원인</td><td><code>-v host/source:/workspace/isaaclab/source:rw</code>가 <code>.pth</code> 참조 파괴</td></tr><tr><td>해결</td><td>editable install된 소스 디렉토리를 마운트하지 않기</td></tr></tbody></table>

```bash
# ❌ 하지 마세요
-v "/opt/isaaclab/source:/workspace/isaaclab/source:rw"

# ✅ 대신 데이터만 마운트
-v "/data/checkpoints:/workspace/isaaclab/logs:rw"
```

***

### 12. 셰이더 캐시 첫 실행 지연

<table><thead><tr><th width="222.359375"></th><th></th></tr></thead><tbody><tr><td>증상</td><td>훈련 시작 후 4분간 아무 출력 없음 (행 걸린 줄 착각)</td></tr><tr><td>원인</td><td>Isaac Sim의 Vulkan RtPso 셰이더 파이프라인 첫 컴파일</td></tr><tr><td>해결</td><td>인내심 + 캐시 볼륨 마운트로 재컴파일 방지</td></tr></tbody></table>

```bash
-v "$CACHE_DIR/kit:/isaac-sim/kit/cache:rw"
```

***

## 빠른 참조 표

| #  | 함정             | 카테고리   | 심각도  |
| -- | -------------- | ------ | ---- |
| 1  | dpkg lock      | 인프라    | 🟡 중 |
| 2  | EBS 디바이스       | 인프라    | 🟡 중 |
| 3  | Instance store | 인프라    | 🟡 중 |
| 4  | templatefile   | 인프라    | 🟡 중 |
| 5  | user\_data 재실행 | 인프라    | 🟢 하 |
| 6  | NGC 이미지 없음     | Docker | 🔴 상 |
| 7  | 코어 패키지 누락      | Docker | 🔴 상 |
| 8  | Entrypoint 모드  | Docker | 🔴 상 |
| 9  | 스크립트 경로        | Docker | 🟡 중 |
| 10 | 빌드 격리          | Docker | 🔴 상 |
| 11 | Volume mount   | Docker | 🟡 중 |
| 12 | 셰이더 캐시         | 런타임    | 🟢 하 |

***

👈 [Lab 7: 정리 및 다음 단계](07-cleanup.md) 👉 [Appendix B: 비용 분석 & 최적화](appendix-b-cost.md)

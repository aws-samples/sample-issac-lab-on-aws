#!/usr/bin/env bash
# =============================================================================
# Isaac Lab Headless Training — Bootstrap Script
# Target: g6e.4xlarge (1× NVIDIA L40S 48 GB, 16 vCPU, 128 GiB RAM)
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/isaac-lab-setup.log) 2>&1

echo "===== [$(date)] Isaac Lab setup starting ====="

# --------------------------------------------------------------------------- #
# 0. System packages
# --------------------------------------------------------------------------- #
export DEBIAN_FRONTEND=noninteractive

# Stop unattended-upgrades to prevent dpkg lock contention
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true

# Kill any running dpkg/apt processes and wait for them to exit
killall -q apt-get dpkg 2>/dev/null || true
sleep 5

# Wait for dpkg lock with retries
for attempt in $(seq 1 12); do
  if apt-get update -qq -o DPkg::Lock::Timeout=60 2>&1; then
    break
  fi
  echo "apt-get update failed (attempt $attempt/12), retrying in 15s..."
  sleep 15
done

apt-get install -y -qq -o DPkg::Lock::Timeout=120 \
  awscli jq htop nvtop tree unzip \
  linux-headers-$(uname -r) \
  build-essential

# --------------------------------------------------------------------------- #
# 1. Mount data EBS volume
# --------------------------------------------------------------------------- #
DATA_MNT="/data"

# On Nitro instances, EBS volumes appear as /dev/nvme*n1, not /dev/xvd*.
# Find the unformatted, unmounted EBS volume (not root, not instance store).
find_data_device() {
  for dev in /dev/nvme*n1; do
    [ -b "$dev" ] || continue
    # Skip if it has partitions (likely root volume)
    if lsblk -no CHILDREN "$dev" 2>/dev/null | grep -q .; then
      # Has children/partitions — check if any are mounted as root
      if lsblk -no MOUNTPOINT "$dev" 2>/dev/null | grep -q "^/$"; then
        continue
      fi
    fi
    # Skip if already mounted (e.g., instance store with LVM)
    if lsblk -no MOUNTPOINT "$dev" 2>/dev/null | grep -q .; then
      continue
    fi
    # Skip if part of LVM
    if pvs "$dev" 2>/dev/null | grep -q "$dev"; then
      continue
    fi
    echo "$dev"
    return
  done
}

# Wait for EBS attachment
DATA_DEV=""
for i in $(seq 1 30); do
  DATA_DEV=$(find_data_device)
  [ -n "$DATA_DEV" ] && break
  echo "Waiting for data EBS volume ($i/30)..."
  sleep 5
done

if [ -n "$DATA_DEV" ] && [ -b "$DATA_DEV" ]; then
  echo "Found data EBS volume at $DATA_DEV"
  # Format only if no filesystem exists
  if ! blkid "$DATA_DEV" | grep -q ext4; then
    mkfs.ext4 -L isaac-data "$DATA_DEV"
  fi
  mkdir -p "$DATA_MNT"
  mount "$DATA_DEV" "$DATA_MNT"
  echo "$DATA_DEV $DATA_MNT ext4 defaults,nofail 0 2" >> /etc/fstab
  mkdir -p "$DATA_MNT"/{datasets,checkpoints,logs,cache}
  chmod -R 755 "$DATA_MNT"
else
  echo "WARNING: Data EBS volume not found, creating /data on root volume"
  mkdir -p "$DATA_MNT"/{datasets,checkpoints,logs,cache}
  chmod -R 755 "$DATA_MNT"
fi

# --------------------------------------------------------------------------- #
# 2. Mount instance store NVMe (scratch / shader cache)
# --------------------------------------------------------------------------- #
# On DL AMIs, the instance store NVMe is often already mounted via LVM at
# /opt/dlami/nvme. Reuse that if available; otherwise find and mount manually.
if mountpoint -q /opt/dlami/nvme 2>/dev/null; then
  echo "Instance store already mounted at /opt/dlami/nvme — symlinking /scratch"
  mkdir -p /opt/dlami/nvme/scratch
  ln -sfn /opt/dlami/nvme/scratch /scratch
  mkdir -p /scratch/{isaac-sim-cache,tmp}
  chmod -R 755 /scratch
else
  # Find an unmounted NVMe instance store (non-EBS)
  for dev in /dev/nvme*n1; do
    [ -b "$dev" ] || continue
    # Skip EBS volumes (they have a serial starting with "vol")
    if nvme id-ctrl "$dev" 2>/dev/null | grep -qi "Amazon Elastic Block Store"; then
      continue
    fi
    if ! mountpoint -q "$(lsblk -no MOUNTPOINT "$dev" 2>/dev/null | head -1)" 2>/dev/null; then
      mkfs.ext4 -L scratch "$dev"
      mkdir -p /scratch
      mount "$dev" /scratch
      mkdir -p /scratch/{isaac-sim-cache,tmp}
      chmod -R 755 /scratch
      break
    fi
  done
fi

# --------------------------------------------------------------------------- #
# 3. Verify NVIDIA driver + Docker
# --------------------------------------------------------------------------- #
echo "===== NVIDIA Driver ====="
nvidia-smi || { echo "FATAL: nvidia-smi failed"; exit 1; }

echo "===== Docker ====="
docker --version || { echo "FATAL: Docker not found"; exit 1; }

# Ensure NVIDIA Container Toolkit runtime is configured
if ! docker info 2>/dev/null | grep -q nvidia; then
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker
fi

# --------------------------------------------------------------------------- #
# 4. NGC login & pull Isaac Sim base image
# --------------------------------------------------------------------------- #
NGC_KEY="${ngc_api_key}"
if [ -n "$NGC_KEY" ]; then
  # Non-fatal: isaac-sim images are publicly pullable, so an expired/invalid
  # key must not abort the whole bootstrap (set -e). Clear any bad stored
  # credentials so anonymous pulls still work.
  if ! echo "$NGC_KEY" | docker login nvcr.io --username '$oauthtoken' --password-stdin; then
    echo "WARN: NGC login failed — continuing with anonymous pull"
    docker logout nvcr.io 2>/dev/null || true
  fi
fi

ISAAC_SIM_IMAGE="nvcr.io/nvidia/isaac-sim:${isaac_sim_version}"
echo "Pulling $ISAAC_SIM_IMAGE ..."
docker pull "$ISAAC_SIM_IMAGE"

# --------------------------------------------------------------------------- #
# 5. Pull Isaac Lab pre-built headless container (if available)
# --------------------------------------------------------------------------- #
ISAAC_LAB_IMAGE="nvcr.io/nvidia/isaac-lab:${isaac_lab_version}"
echo "Attempting to pull $ISAAC_LAB_IMAGE ..."
docker pull "$ISAAC_LAB_IMAGE" 2>/dev/null || {
  echo "Pre-built Isaac Lab image not available — will build from source."
  ISAAC_LAB_IMAGE=""
}

# --------------------------------------------------------------------------- #
# 6. Clone Isaac Lab source (always useful for custom envs)
# --------------------------------------------------------------------------- #
ISAACLAB_DIR="/opt/isaaclab"
if [ ! -d "$ISAACLAB_DIR" ]; then
  git clone --depth 1 --branch "${isaac_lab_version}" \
    https://github.com/isaac-sim/IsaacLab.git "$ISAACLAB_DIR" 2>/dev/null || \
  git clone --depth 1 \
    https://github.com/isaac-sim/IsaacLab.git "$ISAACLAB_DIR"
fi

# --------------------------------------------------------------------------- #
# 7. Build Isaac Lab Docker image from source (fallback)
# --------------------------------------------------------------------------- #
if [ -z "$ISAAC_LAB_IMAGE" ] && [ -f "$ISAACLAB_DIR/docker/container.py" ]; then
  echo "Building Isaac Lab Docker image from source..."
  cd "$ISAACLAB_DIR"
  # v2.1.0 interface: 'start [profile]' builds the image and starts the
  # container detached (there is no --no-enter flag). Pipe 'n' to answer the
  # X11-forwarding prompt — cloud-init has no stdin and input() would crash.
  # Non-fatal, but loud:
  echo n | python3 docker/container.py start base || \
    echo "WARN: Isaac Lab image build failed — run 'python3 docker/container.py start base' in $ISAACLAB_DIR manually"
fi

# --------------------------------------------------------------------------- #
# 8. Create convenience wrapper scripts
# --------------------------------------------------------------------------- #

# ---- isaac-lab-run: launch headless training inside container ----
cat > /usr/local/bin/isaac-lab-run << 'WRAPPER'
#!/usr/bin/env bash
# Usage: isaac-lab-run <script.py> [args...]
# Example: isaac-lab-run source/standalone/workflows/rsl_rl/train.py \
#            --task Isaac-Velocity-Rough-Anymal-C-v0 --headless
set -euo pipefail

ISAAC_SIM_CACHE="/scratch/isaac-sim-cache"
mkdir -p "$ISAAC_SIM_CACHE"/{kit,ov,pip,glcache,computecache}
mkdir -p /data/logs /data/checkpoints

docker run --rm --gpus all --network=host \
  --entrypoint /workspace/isaaclab/isaaclab.sh \
  -e "ACCEPT_EULA=Y" -e "PRIVACY_CONSENT=Y" \
  -v "$ISAAC_SIM_CACHE/kit:/isaac-sim/kit/cache:rw" \
  -v "$ISAAC_SIM_CACHE/ov:/root/.cache/ov:rw" \
  -v "$ISAAC_SIM_CACHE/pip:/root/.cache/pip:rw" \
  -v "$ISAAC_SIM_CACHE/glcache:/root/.cache/nvidia/GLCache:rw" \
  -v "$ISAAC_SIM_CACHE/computecache:/root/.nv/ComputeCache:rw" \
  -v "/data/logs:/root/.nvidia-omniverse/logs:rw" \
  -v "/data/checkpoints:/workspace/isaaclab/logs:rw" \
  -v "/opt/isaaclab/source:/workspace/isaaclab/source:rw" \
  isaac-lab-base:latest \
  -p "$@"
WRAPPER
chmod +x /usr/local/bin/isaac-lab-run

# ---- isaac-sim-shell: interactive shell in Isaac Sim container ----
cat > /usr/local/bin/isaac-sim-shell << 'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

ISAAC_SIM_CACHE="/scratch/isaac-sim-cache"
mkdir -p "$ISAAC_SIM_CACHE"/{kit,ov,pip,glcache,computecache}

docker run --name isaac-sim --entrypoint bash -it --gpus all \
  -e "ACCEPT_EULA=Y" --rm --network=host \
  -e "PRIVACY_CONSENT=Y" \
  -v "$ISAAC_SIM_CACHE/kit:/isaac-sim/kit/cache:rw" \
  -v "$ISAAC_SIM_CACHE/ov:/root/.cache/ov:rw" \
  -v "$ISAAC_SIM_CACHE/pip:/root/.cache/pip:rw" \
  -v "$ISAAC_SIM_CACHE/glcache:/root/.cache/nvidia/GLCache:rw" \
  -v "$ISAAC_SIM_CACHE/computecache:/root/.nv/ComputeCache:rw" \
  -v "/data/logs:/root/.nvidia-omniverse/logs:rw" \
  -v "/data:/data:rw" \
  -v "/opt/isaaclab:/workspace/isaaclab:rw" \
  nvcr.io/nvidia/isaac-sim:$${ISAAC_SIM_TAG:-4.5.0}
WRAPPER
chmod +x /usr/local/bin/isaac-sim-shell

# ---- sync-checkpoints: push checkpoints to S3 ----
cat > /usr/local/bin/sync-checkpoints << 'WRAPPER'
#!/usr/bin/env bash
aws s3 sync /data/checkpoints/ "s3://${checkpoint_bucket}/$(hostname)/" \
  --exclude "*.tmp" --exclude "__pycache__/*"
echo "[$(date)] Checkpoint sync complete."
WRAPPER
chmod +x /usr/local/bin/sync-checkpoints

# ---- Cron: sync checkpoints every 30 min ----
CRON_LINE="*/30 * * * * /usr/local/bin/sync-checkpoints >> /data/logs/sync.log 2>&1"
(crontab -l 2>/dev/null || true; echo "$CRON_LINE") | crontab -

# --------------------------------------------------------------------------- #
# 9. GPU monitoring with CloudWatch (optional)
# --------------------------------------------------------------------------- #
cat > /opt/gpu_monitor.sh << 'MONITOR'
#!/usr/bin/env bash
# Lightweight GPU metrics → CloudWatch custom namespace
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id \
  -H "X-aws-ec2-metadata-token: $(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')")
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region \
  -H "X-aws-ec2-metadata-token: $(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')")

GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
GPU_MEM=$(nvidia-smi --query-gpu=utilization.memory --format=csv,noheader,nounits | head -1)
GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1)

aws cloudwatch put-metric-data --region "$REGION" --namespace "CWAgent" \
  --metric-data "[
    {\"MetricName\":\"GPUUtilization\",\"Value\":$GPU_UTIL,\"Unit\":\"Percent\",\"Dimensions\":[{\"Name\":\"InstanceId\",\"Value\":\"$INSTANCE_ID\"}]},
    {\"MetricName\":\"GPUMemoryUtilization\",\"Value\":$GPU_MEM,\"Unit\":\"Percent\",\"Dimensions\":[{\"Name\":\"InstanceId\",\"Value\":\"$INSTANCE_ID\"}]},
    {\"MetricName\":\"GPUTemperature\",\"Value\":$GPU_TEMP,\"Unit\":\"None\",\"Dimensions\":[{\"Name\":\"InstanceId\",\"Value\":\"$INSTANCE_ID\"}]}
  ]"
MONITOR
chmod +x /opt/gpu_monitor.sh

GPU_CRON="*/5 * * * * /opt/gpu_monitor.sh >> /data/logs/gpu_monitor.log 2>&1"
(crontab -l 2>/dev/null || true; echo "$GPU_CRON") | crontab -

# --------------------------------------------------------------------------- #
# 10. Done
# --------------------------------------------------------------------------- #
echo "===== [$(date)] Isaac Lab setup COMPLETE ====="
echo ""
echo "  Instance:  g6e.4xlarge (1× L40S 48 GB, 16 vCPU, 128 GiB RAM)"
echo "  Data vol:  /data  (EBS gp3)"
echo "  Scratch:   /scratch  (NVMe instance store)"
echo "  Isaac Lab: /opt/isaaclab"
echo ""
echo "  Quick start:"
echo "    isaac-lab-run source/standalone/workflows/rsl_rl/train.py \\"
echo "      --task Isaac-Velocity-Rough-Anymal-C-v0 --headless"
echo ""
echo "    isaac-sim-shell   # interactive shell"
echo "    sync-checkpoints  # manual S3 sync"

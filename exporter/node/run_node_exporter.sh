#!/bin/bash

set -euo pipefail

# ============================================================
# Node Exporter
# Podman Pod構成
#
# AlmaLinux 9
#
# Host
#  └─ monitoring-pod
#      ├─ node-exporter     :9100
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NODE_EXPORTER_IMAGE="quay.io/prometheus/node-exporter:latest"

echo "=========================================="
echo "Node Exporter setup"
echo "=========================================="

# ------------------------------------------------------------
# 1. 必要コマンド確認
# ------------------------------------------------------------

if ! command -v podman >/dev/null 2>&1; then
    echo "ERROR: podman がインストールされていません。"
    exit 1
fi

# コンテナ単体実行の場合PODは不要

# ------------------------------------------------------------
# 2. Node Exporter起動
# ------------------------------------------------------------

# podman はルートレスのため、ホストのポートを開放する場合はfirewalldの設定が必要
sudo firewall-cmd --permanent --add-port=9100/tcp
sudo firewall-cmd --reload

echo "Starting Node Exporter..."
podman rm -f node-exporter || true
podman run -d \
  -p 9100:9100 \
  --name node-exporter \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  "$NODE_EXPORTER_IMAGE" \
  --path.rootfs=/host

# ------------------------------------------------------------
# 3. 起動確認
# ------------------------------------------------------------

echo "[3/3] Checking containers..."

sleep 3

echo
echo "===== Containers ====="
podman ps
podman logs -f node-exporter &

echo
echo "===== Node Exporter readiness ====="

if curl -fsS http://localhost:9100/metrics; then
    echo
    echo "Node Exporter: OK"
else
    echo
    echo "Node Exporter: FAILED"
fi

echo
echo "=========================================="
echo "Setup completed."
echo "=========================================="

echo
echo "Node Exporter:"
echo "  http://localhost:9100"

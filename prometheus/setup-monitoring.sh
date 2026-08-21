#!/bin/bash

set -euo pipefail

# ============================================================
# Prometheus + Blackbox Exporter
# Podman Pod構成
#
# AlmaLinux 9
#
# Host
#  └─ monitoring-pod
#      ├─ prometheus         :9090
#      └─ blackbox-exporter :9115
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD_NAME="monitoring-pod"

PROMETHEUS_IMAGE="quay.io/prometheus/prometheus:v3.13.1"
BLACKBOX_IMAGE="quay.io/prometheus/blackbox-exporter:v0.28.0"
ALERTMANAGER_IMAGE="quay.io/prometheus/alertmanager:v0.28.1"

PROMETHEUS_DIR="${SCRIPT_DIR}/prometheus"
BLACKBOX_DIR="${SCRIPT_DIR}/blackbox"
ALERTMANAGER_DIR="${SCRIPT_DIR}/alertmanager"
ALERTMANAGER_TEMPLATE_DIR="${ALERTMANAGER_DIR}/templates"

PROMETHEUS_CONFIG="${PROMETHEUS_DIR}/prometheus.yml"
PROMETHEUS_ALERTS="${PROMETHEUS_DIR}/alerts.yml"
PROMETHEUS_TARGETS="${PROMETHEUS_DIR}/targets"
BLACKBOX_CONFIG="${BLACKBOX_DIR}/blackbox.yml"
ALERTMANAGER_CONFIG="${ALERTMANAGER_DIR}/alertmanager.yml"
ALERTMANAGER_TEMPLATE="${ALERTMANAGER_TEMPLATE_DIR}/default.tmpl"

echo "=========================================="
echo "Prometheus + Blackbox Exporter setup"
echo "=========================================="

# ------------------------------------------------------------
# 1. 必要コマンド確認
# ------------------------------------------------------------

if ! command -v podman >/dev/null 2>&1; then
    echo "ERROR: podman がインストールされていません。"
    exit 1
fi

# ------------------------------------------------------------
# 2. ディレクトリ作成
# ------------------------------------------------------------

echo "[1/7] Creating directories..."

mkdir -p "${PROMETHEUS_DIR}"
mkdir -p "${BLACKBOX_DIR}"
mkdir -p "${ALERTMANAGER_TEMPLATE_DIR}"

# ------------------------------------------------------------
# 5. 既存Podの扱い
# ------------------------------------------------------------

echo "[4/7] Checking existing Pod..."

if podman pod exists "${POD_NAME}"; then
    echo "Existing pod '${POD_NAME}' found."

    echo "Stopping and removing existing pod..."

    podman pod stop "${POD_NAME}" >/dev/null 2>&1 || true
    podman pod rm "${POD_NAME}" >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------
# 6. Pod作成
# ------------------------------------------------------------

echo "[5/7] Creating Pod..."

podman pod create \
    --name "${POD_NAME}" \
    -p 9090:9090 \
    -p 9093:9093 \
    -p 9115:9115

# ------------------------------------------------------------
# 7. Alertmanager起動
# ------------------------------------------------------------

echo "Starting Alertmanager..."

podman run -d \
    --name alertmanager \
    --pod "${POD_NAME}" \
    -v "$(realpath "${ALERTMANAGER_CONFIG}"):/etc/alertmanager/alertmanager.yml:Z,ro" \
    -v "$(realpath "${ALERTMANAGER_TEMPLATE}"):/etc/alertmanager/templates/default.tmpl:Z,ro" \
    "${ALERTMANAGER_IMAGE}" \
    --config.file=/etc/alertmanager/alertmanager.yml

# ------------------------------------------------------------
# 8. Blackbox Exporter起動
# ------------------------------------------------------------

echo "Starting Blackbox Exporter..."

podman run -d \
    --name blackbox-exporter \
    --pod "${POD_NAME}" \
    -v "$(realpath "${BLACKBOX_CONFIG}"):/config/blackbox.yml:Z,ro" \
    "${BLACKBOX_IMAGE}" \
    --config.file=/config/blackbox.yml

# ------------------------------------------------------------
# 9. Prometheus起動
# ------------------------------------------------------------

echo "Starting Prometheus..."

podman run -d \
    --name prometheus \
    --pod "${POD_NAME}" \
    -v "$(realpath "${PROMETHEUS_CONFIG}"):/etc/prometheus/prometheus.yml:Z,ro" \
    -v "$(realpath "${PROMETHEUS_ALERTS}"):/etc/prometheus/alerts.yml:Z,ro" \
    -v "$(realpath "${PROMETHEUS_TARGETS}"):/etc/prometheus/targets:Z,ro" \
    "${PROMETHEUS_IMAGE}" \
    --config.file=/etc/prometheus/prometheus.yml

# ------------------------------------------------------------
# 10. 起動確認
# ------------------------------------------------------------

echo "[6/7] Checking containers..."

sleep 3

echo
echo "===== Pod ====="
podman pod ps

echo
echo "===== Containers ====="
podman ps \
    --filter "pod=${POD_NAME}" \
    --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "===== Prometheus readiness ====="

if curl -fsS http://localhost:9090/-/ready; then
    echo
    echo "Prometheus: OK"
else
    echo
    echo "Prometheus: FAILED"
fi

echo
echo "===== Alertmanager health ====="

if curl -fsS http://localhost:9093/-/healthy; then
    echo
    echo "Alertmanager: OK"
else
    echo
    echo "Alertmanager: FAILED"
fi

echo
echo "===== Blackbox Exporter health ====="

if curl -fsS http://localhost:9115/-/healthy; then
    echo
    echo "Blackbox Exporter: OK"
else
    echo
    echo "Blackbox Exporter: FAILED"
fi

echo
echo "=========================================="
echo "Setup completed."
echo "=========================================="

echo
echo "Prometheus:"
echo "  http://localhost:9090"

echo
echo "Alertmanager:"
echo "  http://localhost:9093"

echo
echo "Blackbox Exporter:"
echo "  http://localhost:9115"

echo
echo "Target:"
echo "  https://prometheus.io"

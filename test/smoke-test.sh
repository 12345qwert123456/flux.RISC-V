#!/usr/bin/env bash
# =============================================================================
# test/smoke-test.sh — Validates a linux/riscv64 FluxCD Docker image.
#
# Checks performed:
#   1. Image architecture is riscv64 (no QEMU needed — inspects OCI manifest).
#   2. Binary exists at the expected path inside the container (QEMU required).
#   3. Binary executes without crashing (exit code < 128 = no signal/segfault).
#      - If SMOKE_CMD is provided, run that command and expect exit 0.
#      - If SMOKE_CMD is empty, launch the binary with a 5-second timeout;
#        a clean error exit (e.g. "missing kubeconfig") is treated as PASS.
#
# Prerequisites:
#   - Docker with BuildKit + QEMU binfmt registered for riscv64.
#     On GitHub Actions: docker/setup-qemu-action@v3 (platforms: riscv64).
#     Locally (Linux): docker run --privileged --rm tonistiigi/binfmt --install riscv64
#     Locally (Docker Desktop / Mac / Win): binfmt support is built in.
#
# Usage:
#   ./smoke-test.sh <image> [binary] [smoke_cmd]
#
# Examples:
#   ./smoke-test.sh flux:v2.5.1-riscv64 /usr/local/bin/flux "version --client"
#   ./smoke-test.sh source-controller:v1.5.1-riscv64 /manager
# =============================================================================

set -euo pipefail

# ── Arguments ────────────────────────────────────────────────────────────────
IMAGE="${1:?Usage: $0 <image> [binary] [smoke_cmd]}"
BINARY="${2:-/manager}"
SMOKE_CMD="${3:-}"

# ── Colours ───────────────────────────────────────────────────────────────────
PASS="\033[0;32mPASS\033[0m"
FAIL="\033[0;31mFAIL\033[0m"
INFO="\033[0;34mINFO\033[0m"

_pass() { printf "  [%b] %s\n" "${PASS}" "$*"; }
_fail() { printf "  [%b] %s\n" "${FAIL}" "$*"; exit 1; }
_info() { printf "  [%b] %s\n" "${INFO}" "$*"; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Smoke test: ${IMAGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Check 1: OCI manifest architecture ───────────────────────────────────────
# Uses docker inspect which reads local image metadata — no QEMU required.
ARCH=$(docker inspect --format='{{.Architecture}}' "${IMAGE}" 2>/dev/null)
if [ "${ARCH}" != "riscv64" ]; then
  _fail "Architecture: expected riscv64, got '${ARCH}'"
fi
_pass "Architecture: ${ARCH}"

# ── Check 2: Binary exists inside the container ───────────────────────────────
# Overrides the entrypoint with 'ls' to test path existence.
# Requires QEMU binfmt to be registered.
_info "Checking binary: ${BINARY}"
if ! docker run --platform linux/riscv64 --rm \
       --entrypoint ls "${IMAGE}" "${BINARY}" > /dev/null 2>&1; then
  _fail "Binary not found at ${BINARY}"
fi
_pass "Binary exists: ${BINARY}"

# ── Check 3: Binary execution ─────────────────────────────────────────────────
if [ -n "${SMOKE_CMD}" ]; then
  # Known-good command (e.g. "version --client" for flux CLI).
  # We expect exit code 0.
  _info "Running: docker run --platform linux/riscv64 --rm ${IMAGE} ${SMOKE_CMD}"
  OUTPUT=$(docker run --platform linux/riscv64 --rm "${IMAGE}" ${SMOKE_CMD} 2>&1) || {
    EXIT=$?
    _fail "Command exited with ${EXIT}. Output:\n${OUTPUT}"
  }
  echo "${OUTPUT}"
  _pass "Binary executed successfully (exit 0)"

else
  # Controllers: launch with a 5-second timeout.
  # Expected: binary starts, fails with error about missing kubeconfig (exit 1).
  # NOT expected: signal-terminated crash (exit >= 128, e.g. 139 = SIGSEGV).
  _info "Running: docker run --platform linux/riscv64 --rm ${IMAGE}  (5 s timeout)"
  EXIT=0
  timeout 5 docker run --platform linux/riscv64 --rm "${IMAGE}" 2>&1 || EXIT=$?

  if [ "${EXIT}" -eq 124 ]; then
    _pass "Binary started and ran for 5 s (timeout as expected — no k8s config)"
  elif [ "${EXIT}" -gt 127 ]; then
    _fail "Binary terminated by signal (exit ${EXIT} — possible segfault/crash)"
  else
    _pass "Binary exited cleanly (exit ${EXIT} — expected config-missing error)"
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf " Result: [%b] %s\n" "${PASS}" "${IMAGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# syntax=docker/dockerfile:1.7
# =============================================================================
# Builds the flux CLI (fluxcd/flux2) for linux/riscv64 WITHOUT QEMU at build
# time. Cross-compilation is handled by tonistiigi/xx on the native host.
# The final stage contains NO RUN instructions, so Docker never needs to
# execute riscv64 code during the image build.
#
# QEMU binfmt is only required when RUNNING the resulting image (smoke tests).
#
# Usage:
#   docker buildx build \
#     --platform linux/riscv64 \
#     --build-arg VERSION=v2.5.1 \
#     --load \
#     -t flux:v2.5.1-riscv64 \
#     dockerfiles/flux2/
# =============================================================================

ARG GO_VERSION=1.26
ARG XX_VERSION=1.9.0
ARG ALPINE_VERSION=3.23

# -----------------------------------------------------------------------------
# xx cross-compilation tools (runs on native BUILDPLATFORM)
# -----------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

# -----------------------------------------------------------------------------
# Stage 1 – compile (runs on native BUILDPLATFORM, no QEMU needed)
# -----------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS builder

ARG TARGETPLATFORM
ARG VERSION

COPY --from=xx / /

# bash + make + curl needed for bundle.sh (kustomize manifest generation)
RUN apk add --no-cache git ca-certificates bash curl

# Install kustomize (native amd64/arm64 binary – runs on BUILDPLATFORM)
ARG KUSTOMIZE_VERSION=5.6.0
RUN ARCH=$(xx-info march) && \
    case "${ARCH}" in \
      x86_64)  KZ_ARCH=amd64 ;; \
      aarch64) KZ_ARCH=arm64 ;; \
      *)        KZ_ARCH=amd64 ;; \
    esac && \
    curl -sSfL \
      "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${KZ_ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin kustomize && \
    kustomize version

RUN git clone --depth 1 --branch "${VERSION}" \
      https://github.com/fluxcd/flux2 /src

WORKDIR /src

# Generate the embedded manifests (cmd/flux/manifests/*.yaml)
RUN bash ./manifests/scripts/bundle.sh

RUN CGO_ENABLED=0 xx-go build \
      -trimpath \
      -ldflags="-s -w -X main.Version=${VERSION}" \
      -o /flux ./cmd/flux && \
    xx-verify --static /flux

# -----------------------------------------------------------------------------
# Stage 2 – CA certificates (runs on native BUILDPLATFORM, no QEMU needed)
# -----------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS certs
RUN apk add --no-cache ca-certificates

# -----------------------------------------------------------------------------
# Stage 3 – final riscv64 image (NO RUN → no QEMU during build)
# -----------------------------------------------------------------------------
FROM --platform=$TARGETPLATFORM alpine:${ALPINE_VERSION}

COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /flux /usr/local/bin/flux

USER 65534:65534
ENTRYPOINT ["flux"]

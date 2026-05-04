# syntax=docker/dockerfile:1.7
# =============================================================================
# Builds helm-controller (fluxcd/helm-controller) for linux/riscv64
# WITHOUT QEMU at build time. Cross-compilation is handled by tonistiigi/xx
# on the native host. The final stage contains NO RUN instructions, so Docker
# never needs to execute riscv64 code during the image build.
#
# QEMU binfmt is only required when RUNNING the resulting image (smoke tests).
#
# Usage:
#   docker buildx build \
#     --platform linux/riscv64 \
#     --build-arg VERSION=v1.2.0 \
#     --load \
#     -t helm-controller:v1.2.0-riscv64 \
#     dockerfiles/helm-controller/
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

RUN apk add --no-cache git ca-certificates

RUN git clone --depth 1 --branch "${VERSION}" \
      https://github.com/fluxcd/helm-controller /src

WORKDIR /src

RUN CGO_ENABLED=0 xx-go build \
      -trimpath \
      -ldflags="-s -w" \
      -o /manager . && \
    xx-verify --static /manager

# -----------------------------------------------------------------------------
# Stage 2 – CA certificates + tzdata (runs on native BUILDPLATFORM)
# -----------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS certs
RUN apk add --no-cache ca-certificates tzdata

# -----------------------------------------------------------------------------
# Stage 3 – final riscv64 image (NO RUN → no QEMU during build)
# -----------------------------------------------------------------------------
FROM --platform=$TARGETPLATFORM alpine:${ALPINE_VERSION}

COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=certs /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /manager /manager

USER 65534:65534
ENTRYPOINT ["/manager"]

# Flux CD RISC-V — Agent Instructions

Cross-compiles all 7 FluxCD components to `linux/riscv64` using Docker buildx + [tonistiigi/xx](https://github.com/tonistiigi/xx). No QEMU at build time; QEMU is only needed at smoke-test time.

## Repository Layout

```
dockerfiles/<component>/Dockerfile   # one per component
test/smoke-test.sh                   # post-build validation
.github/workflows/build-riscv64.yml  # CI matrix (all 7 components)
```

## Components & Pinned Versions

| Component | Version | Binary | Extra |
|---|---|---|---|
| flux2 (CLI) | v2.5.1 | `/usr/local/bin/flux` | smoke_cmd: `version --client` |
| source-controller | **v1.5.0** (not v1.5.1 — doesn't exist) | `/manager` | |
| kustomize-controller | v1.5.1 | `/manager` | |
| helm-controller | v1.2.1 | `/manager` | |
| notification-controller | v1.5.0 | `/manager` | |
| image-reflector-controller | v0.34.0 | `/manager` | |
| image-automation-controller | v0.40.0 | `/manager` | |

## Local Build Commands

```powershell
# Single component (run from workspace root)
docker buildx build --builder desktop-linux --platform linux/riscv64 `
  --build-arg VERSION=<version> --load -t <image>:<version>-riscv64 `
  dockerfiles/<component>/

# All 7 — example for source-controller
docker buildx build --builder desktop-linux --platform linux/riscv64 `
  --build-arg VERSION=v1.5.0 --load -t source-controller:v1.5.0-riscv64 `
  dockerfiles/source-controller/
```

Builder name is `desktop-linux` (Docker Desktop on Windows/Mac).

## Smoke Tests

```bash
bash test/smoke-test.sh <image>:<version>-riscv64 [binary] [smoke_cmd]

# Examples
bash test/smoke-test.sh flux:v2.5.1-riscv64 /usr/local/bin/flux "version --client"
bash test/smoke-test.sh source-controller:v1.5.0-riscv64 /manager
```

Checks: (1) `docker inspect` reports `Architecture=riscv64`, (2) binary path exists, (3) binary runs without segfault. Requires QEMU binfmt for checks 2–3 (built-in on Docker Desktop).

## Dockerfile Conventions

All Dockerfiles follow a **3-stage pattern**:

1. **`AS xx`** — `FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx` — cross-compilation helpers
2. **`AS builder`** — native build stage; uses `xx-go build` and `xx-verify --static`
3. **`AS certs`** — extracts CA certs / tzdata on BUILDPLATFORM
4. **Final stage** — `FROM --platform=$TARGETPLATFORM alpine:${ALPINE_VERSION}` — **NO RUN instructions** (avoids QEMU at build time)

### Critical Pitfalls

- **Named `xx` stage is mandatory.** `COPY --from=tonistiigi/xx:${XX_VERSION}` fails because ARG values are not interpolated in `COPY --from=`. Always use: `FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx` then `COPY --from=xx / /`.
- **flux2 requires `bundle.sh` before `go build`.** Run `bash ./manifests/scripts/bundle.sh` inside `/src` before `xx-go build` or the embedded FS (`cmd/flux/manifests/*.yaml`) will be empty and the build fails.
- **flux2 needs kustomize on BUILDPLATFORM** to run bundle.sh. Install a native binary matching the builder arch (amd64/arm64) from `kubernetes-sigs/kustomize` releases; pinned at v5.6.0.
- **Final stage must have zero `RUN` instructions.** Any `RUN` in the final stage attempts to execute riscv64 code during build, requiring QEMU.

## CI Workflow

See [.github/workflows/build-riscv64.yml](.github/workflows/build-riscv64.yml):
- Matrix over all 7 components; each job is independent (`fail-fast: false`)
- Triggers: push to `main` (Dockerfile/test changes), weekly schedule, `workflow_dispatch` (optional single-component input)
- GHA layer cache per component: `type=gha,scope=<name>`
- Artifacts: `docker save | gzip` → uploaded as `<image>-<version>-riscv64.tar.gz`, retained 30 days
- QEMU registered via `docker/setup-qemu-action@v3 (platforms: riscv64)` before smoke tests

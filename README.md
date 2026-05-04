# FluxCD for RISC-V (linux/riscv64)

Unofficial automated builds of all 7 [FluxCD](https://github.com/fluxcd) components for the `linux/riscv64` architecture.

**No patches are applied.** Upstream sources are cloned at release tags and built directly. This repository contains only the build infrastructure (Dockerfiles + CI workflow).

---

## How it works

| Step | Detail |
|------|--------|
| **Cross-compilation** | `tonistiigi/xx` provides `xx-go build` and `xx-verify --static`, cross-compiling Go binaries on the native amd64 runner — no QEMU at build time |
| **flux2 CLI** | Requires `kustomize` on the builder to run `manifests/scripts/bundle.sh` and embed manifest files before `go build` |
| **Final stage** | Alpine base image with **zero `RUN` instructions** — Docker never needs to execute riscv64 code during the image build |
| **Automation** | Weekly cron + push triggers; each matrix job independently skips if the release already exists |

---

## Components

| Component | Docker Hub image | Binary |
|-----------|-----------------|--------|
| flux2 CLI | `<your-dockerhub-username>/flux-riscv64` | `/usr/local/bin/flux` |
| source-controller | `<your-dockerhub-username>/source-controller-riscv64` | `/manager` |
| kustomize-controller | `<your-dockerhub-username>/kustomize-controller-riscv64` | `/manager` |
| helm-controller | `<your-dockerhub-username>/helm-controller-riscv64` | `/manager` |
| notification-controller | `<your-dockerhub-username>/notification-controller-riscv64` | `/manager` |
| image-reflector-controller | `<your-dockerhub-username>/image-reflector-controller-riscv64` | `/manager` |
| image-automation-controller | `<your-dockerhub-username>/image-automation-controller-riscv64` | `/manager` |

Versions are auto-detected from the latest upstream GitHub release at build time.

---

## Usage

### Pull an image

```sh
docker pull <your-dockerhub-username>/flux-riscv64:latest
docker pull <your-dockerhub-username>/source-controller-riscv64:latest
docker pull <your-dockerhub-username>/kustomize-controller-riscv64:latest
docker pull <your-dockerhub-username>/helm-controller-riscv64:latest
docker pull <your-dockerhub-username>/notification-controller-riscv64:latest
docker pull <your-dockerhub-username>/image-reflector-controller-riscv64:latest
docker pull <your-dockerhub-username>/image-automation-controller-riscv64:latest
```

### Run on a RISC-V device

```sh
docker run --platform linux/riscv64 --rm \
  <your-dockerhub-username>/source-controller-riscv64:latest
```

---

## GitHub Releases

Each release is tagged `<component>-<version>-riscv64` (e.g. `source-controller-v1.5.0-riscv64`) and includes:

- `<component>-<version>-riscv64.tar.gz` — Docker image archive (load with `docker load`)
- `SHA256SUMS` — checksums file

### Loading a release image

```sh
docker load < source-controller-v1.5.0-riscv64.tar.gz
docker run --platform linux/riscv64 --rm source-controller:v1.5.0-riscv64
```

---

## Building locally

```powershell
docker buildx build --builder desktop-linux --platform linux/riscv64 `
  --build-arg VERSION=v1.5.0 --load `
  -t source-controller:v1.5.0-riscv64 `
  dockerfiles/source-controller/
```

> Builder name `desktop-linux` is specific to Docker Desktop on Windows/macOS.
> Linux users: `docker buildx create --use && docker buildx build ...`

### Smoke testing a locally built image

```sh
bash test/smoke-test.sh source-controller:v1.5.0-riscv64 /manager
bash test/smoke-test.sh flux:v2.5.1-riscv64 /usr/local/bin/flux "version --client"
```

Checks: (1) architecture is `riscv64`, (2) binary path exists, (3) binary runs without segfault.
Requires QEMU binfmt for steps 2–3 (built-in on Docker Desktop; on Linux run `docker run --privileged --rm tonistiigi/binfmt --install riscv64`).

---

## Repository secrets and variables

Required to publish Docker images and GitHub Releases via the CI workflow:

| Type | Name | Description |
|------|------|-------------|
| Variable | `DOCKERHUB_USERNAME` | Docker Hub username |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub access token |

`GITHUB_TOKEN` is provided automatically by GitHub Actions.

---

## Triggering a manual build

1. Go to **Actions → Build FluxCD for linux/riscv64**
2. Click **Run workflow**
3. Optionally set a specific component (leave empty for all 7)
4. Optionally enable **Force rebuild** to re-publish an existing release

---

## License

The build infrastructure in this repository is licensed under the [MIT License](LICENSE).

FluxCD itself is © FluxCD contributors and licensed under the
[Apache 2.0 License](https://github.com/fluxcd/flux2/blob/main/LICENSE).

# 0005. App and runner are separate images, so an app-only deploy keeps the runner

- **Status:** Accepted
- **Date:** 2026-09-11 (#71); completed 2026-09-25 (#253)
- **Source:** `docs/DESIGN.md` §4; `docs/DEPLOY.md`; `deploy/deploy`

## Context

Every merge to main deploys to the mini-pc. When the `app` and `runner` services shared
one image, every deploy recreated the runner container. That interrupted every run in
flight: each went back to the queue only after the five-minute stale release, then resumed
from its last snapshot and lost up to `snapshot_every` epochs. With several merges an hour,
long runs barely progressed.

## Decision

- The runner has its own image (`life-simulator-runner`), built from a Dockerfile target
  whose only inputs are the Rust build: `engine/`, the `Makefile` and the pinned
  wasm-bindgen version. An app-only change produces identical runner layers (#71).
- The images are built with `BUILDX_NO_DEFAULT_ATTESTATIONS=1`. Under the containerd image
  store, BuildKit's default provenance attestation gave the runner a new image ID on every
  build even when no layer changed, so compose recreated it anyway (#253). The compose file
  sets no `provenance:` key, because Compose 2.40.3 misreads it (docker/compose#14111).
- `deploy/deploy` tags both images `:previous`, and rolls both back when the stack does not
  come up healthy.

## Consequences

- Only an engine change restarts lab runs, which is one reason to batch engine merges.
- `spec/deploy/docker_compose_spec.rb` pins the build variable and the absence of a
  `provenance:` key. The fix itself is verified only by real deploys, which log whether the
  runner image changed.
- Revisit the attestation workaround after a Compose upgrade that carries the upstream fix.

# Deploying Life Simulator

The site runs on the mini-pc (`mini-pc@192.168.1.37`) as a Docker Compose stack —
`db` (Postgres 17), `app` (Rails behind Thruster), `runner` (the Rust engine in lab
mode), `cloudflared` — reached from the internet through a Cloudflare tunnel. Nothing
but the tunnel is exposed: the app is bound to `127.0.0.1:8070` and Postgres to
`127.0.0.1:5433`.

## First-time setup

```sh
ssh mini-pc@192.168.1.37
git clone git@github.com:hanscanonico/life_simulator.git ~/Documents/life_simulator
cd ~/Documents/life_simulator
cp deploy/.env.example deploy/.env && $EDITOR deploy/.env   # fill every value
deploy/deploy --no-pull
```

In the Cloudflare Zero Trust dashboard: create a tunnel named `life-simulator`,
copy its token into `CLOUDFLARE_TUNNEL_TOKEN`, and add the public hostname
`simulator-life.com` → `http://app:8080` (and `www.simulator-life.com` the same
way); `cloudflared` shares the compose network, so `app` is the right hostname.

Nightly backups:

```sh
sudo cp deploy/systemd/life-simulator-backup.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now life-simulator-backup.timer
```

## Routine deploy

```sh
cd ~/Documents/life_simulator && deploy/deploy
```

It fast-forwards to `origin/main` (`DEPLOY_REF=<sha> deploy/deploy` pins another
commit), tags the image currently serving `:previous`, rebuilds, brings the stack up
and waits for both `http://127.0.0.1:8070/up` and every service of the stack being
in state `running` — a container whose start failed is left `Created`, which
`restart: unless-stopped` never acts on, so `up -d` alone is not proof that the site
is served. When the wait times out the script prints `docker compose ps -a`, the
services that are not running and the app's last 50 log lines, retries the start
once, and only then rolls back. `bin/docker-entrypoint` runs `db:prepare` on boot,
so migrations apply themselves. A healthy deploy ends by pruning untagged images
older than a week; `:previous` is tagged, so it always survives.

## Runner

`runner` runs the same image as `app` with a different command: `runner lab` claims
runs from `POST /api/runs/claim` with `RUNNER_TOKEN`, streams samples and snapshots
back, and heartbeats every 30 s. It holds no state of its own — everything it knows
comes from the app.

```sh
docker compose -f deploy/docker-compose.yml logs -f runner
docker compose -f deploy/docker-compose.yml ps runner
```

Scaling: `RUNNER_PARALLELISM` in `deploy/.env` is how many runs execute at once
(default 12, one thread each). The compose limits cap the service at 14 CPUs and 6 GB
whatever that number says, so the site keeps two cores. After changing it:

```sh
docker compose -f deploy/docker-compose.yml up -d runner
```

Restarts and deploys: a stop sends SIGTERM, and the runner flushes its current sample
batch, sends one last heartbeat with `epochs_done` and exits (`stop_grace_period` is
60 s). The run stays claimed until it has been silent for five minutes, then the app
returns it to the queue; the next claim fetches its latest snapshot and continues from
that epoch, so nothing but the epochs since the last snapshot is recomputed. A run that
crashes is reported as `failed` with its error and is not retried.

## Automatic deployment

Green main deploys itself: the `deploy` job of `.github/workflows/ci.yml` runs on the
mini-pc's own self-hosted runner once every other job of the run is green, and does
what a routine deploy does — fast-forward the checkout in
`/home/mini-pc/Documents/life_simulator` to the tested commit, then
`deploy/deploy --no-pull`.

Installing the runner, once, on the mini-pc:

```sh
gh api -X POST repos/hanscanonico/life_simulator/actions/runners/registration-token --jq .token
ssh mini-pc@192.168.1.37
cd ~/Documents/life_simulator
deploy/setup_runner <token>          # registers mini-pc-life with the life-prod label
sudo ~/actions-runner-life/svc.sh install $USER
sudo ~/actions-runner-life/svc.sh start
```

The registration token is short-lived — take it just before running the script. Docker
has to be usable by the runner's user (`sudo usermod -aG docker $USER`, then re-login).

To redeploy without a commit — the current main again, say after editing `deploy/.env` —
use the Actions tab: CI → Run workflow → `main`. The full gate runs first, then the
deploy job.

A failed deploy leaves the site up: `deploy/deploy` rolls back to the `:previous` image
when the new build never turns healthy, and exits non-zero, so the job goes red while
the previous build keeps serving. A stack left half up — the app created but never
started, say — counts as not healthy and goes down the same path, so the site can no
longer sit on a 502 behind a green deploy. The job's log is the deploy log; `docker
compose -f deploy/docker-compose.yml logs app` on the host has the rest.

## Rollback

A deploy that never turns healthy rolls itself back to `:previous` and exits non-zero.
To roll back by hand afterwards:

```sh
docker image tag life-simulator-app:previous life-simulator-app:latest
docker compose -f deploy/docker-compose.yml up -d app
```

## Logs and backups

```sh
docker compose -f deploy/docker-compose.yml logs -f app
deploy/backup_db     # on demand; the timer does this at 01:45
ls ~/backups         # 14 days of custom-format dumps, two per night
docker compose -f deploy/docker-compose.yml exec -T db \
  pg_restore -U life_simulator -d life_simulator_production --clean < ~/backups/<dump>
```

Every service logs to `json-file` capped at 5 x 10 MB, so `logs` only reaches back
that far. Each backup run writes `life_simulator_<stamp>.dump` (everything) beside
`life_simulator_meta_<stamp>.dump`, the same dump without the `snapshots` rows —
small enough to restore casually while snapshots are almost the whole database. Both
are verified with `pg_restore -l` before they take their final name, so a run that
fails leaves the previous backups untouched and exits non-zero:
`systemctl status life-simulator-backup` and `journalctl -u life-simulator-backup`
show it.

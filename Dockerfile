# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t life-simulator-app .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name life-simulator life-simulator-app
#
# It builds two images. The default (last) stage is the Rails app; the `runner`
# stage is the lab runner, built on its own so that a deploy that only changed
# app code cannot restart the runs — see the stage's own comment.
# docker build --target runner -t life-simulator-runner .

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away stage that builds the Rust side: the lab runner the `runner`
# service executes, and the wasm bundle the viewer loads.
FROM docker.io/library/rust:1-slim-bookworm AS rust-build

WORKDIR /src

# wasm-bindgen-cli must match the wasm-bindgen crate the engine links, or the
# generated glue rejects the module: read the version out of the lockfile. Only
# the lockfile is copied at this point, so editing engine source does not
# recompile the CLI — a from-source install of several minutes — on every deploy.
COPY engine/Cargo.lock /src/engine/Cargo.lock
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    rustup target add wasm32-unknown-unknown && \
    cargo install wasm-bindgen-cli --locked \
      --version "$(sed -n '/^name = "wasm-bindgen"$/{n;s/^version = "\(.*\)"$/\1/p;q;}' /src/engine/Cargo.lock)"

COPY Makefile /src/
COPY engine /src/engine/

# The mini-pc is x86-64-v3 (AVX2); the flag is skipped elsewhere so the image
# still builds on an arm64 laptop.
RUN mkdir -p /out && \
    if [ "$(uname -m)" = "x86_64" ]; then export RUSTFLAGS="-C target-cpu=x86-64-v3"; fi && \
    cd /src/engine && cargo build --release -p runner && cp target/release/runner /out/

# Whatever `make wasm` emits into app/assets/wasm is what the image ships; the
# directory is created first so the copy out of this stage never misses.
RUN mkdir -p /src/app/assets/wasm && make -C /src wasm


# Final stage for the runner image
#
# The lab runner ships on its own rather than inside the app image, because the
# `runner` service is restarted whenever the image it runs changes, and every
# restart interrupts the runs in flight: they are only re-queued after the
# 5-minute stale release and resume from their last snapshot. This stage's
# layers read nothing but the rust-build stage, whose own inputs are engine/,
# the Makefile and the wasm-bindgen version pinned in engine/Cargo.lock — no app
# file is copied in — so an app-only merge rebuilds identical layers, BuildKit
# reuses them, and the image ID does not move.
FROM docker.io/library/debian:bookworm-slim AS runner

# The runner talks to the app over HTTP and to nothing else: certificates are
# all this image needs beyond the binary.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Run as a non-root user for security, as the app image does.
RUN groupadd --system --gid 1000 runner && \
    useradd runner --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --from=rust-build /out/runner /usr/local/bin/runner

# `command:` in deploy/docker-compose.yml is the subcommand and its flags, e.g.
# `lab --api http://app:8080`.
ENTRYPOINT ["runner"]


# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# The wasm bundle is a build artifact, not a committed one: take the freshly
# built copy before precompiling, so the asset digests cover it.
COPY --from=rust-build /src/app/assets/wasm/ /rails/app/assets/wasm/

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime.
# HTTP_PORT is set to 8080 in deploy/docker-compose.yml: the unprivileged user
# cannot bind Thruster's default port 80.
EXPOSE 8080
CMD ["./bin/thrust", "./bin/rails", "server"]

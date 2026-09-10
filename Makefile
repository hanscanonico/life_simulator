# Aggregate gate for Life Simulator. `make verify` must be green before any PR.
SHELL := /bin/bash
export PATH := $(HOME)/.cargo/bin:/opt/homebrew/opt/rustup/bin:$(PATH)
ENGINE := engine

.PHONY: verify rails-verify engine-verify wasm test lint fmt

verify: rails-verify engine-verify

rails-verify:
	bundle exec rubocop
	bundle exec brakeman -q --no-pager --no-exit-on-warn --no-exit-on-error
	bundle exec rspec

engine-verify:
	@if [ -f $(ENGINE)/Cargo.toml ]; then \
	  cd $(ENGINE) && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace; \
	  $(MAKE) -C .. wasm; \
	else echo "engine/: not present yet, skipping"; fi

# Builds the wasm crate into app/assets/wasm/ (committed output is NOT the source of truth; the build is).
wasm:
	@if [ -f $(ENGINE)/crates/wasm/Cargo.toml ]; then \
	  cd $(ENGINE) && cargo build -p wasm --target wasm32-unknown-unknown --release; \
	else echo "wasm crate: not present yet, skipping"; fi

test: ; bundle exec rspec
lint: ; bundle exec rubocop -A
fmt:  ; cd $(ENGINE) && cargo fmt --all

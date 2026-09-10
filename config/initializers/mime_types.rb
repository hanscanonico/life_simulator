# frozen_string_literal: true

# Propshaft asks Mime::Type for an asset's content type, and browsers refuse to stream a
# wasm module served as anything but application/wasm.
Mime::Type.register "application/wasm", :wasm

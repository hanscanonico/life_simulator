import { Controller } from "@hotwired/stimulus"

// The engine's metrics are expensive (they compress the whole world), so the readout
// lags the epoch counter by up to this many epochs.
const METRICS_EVERY_EPOCHS = 10

const ERROR_CLASS = "viewer-status--error"

// The copy around the viewer is English, so its numbers are grouped the English way
// whatever locale the browser reports.
const LOCALE = "en-US"

export default class extends Controller {
  static targets = [
    "canvas",
    "status",
    "playLabel",
    "epoch",
    "compressRatio",
    "replicatorCount",
    "distinctTapes",
    "copyRate"
  ]

  static values = {
    worlds: Object,
    substrate: String,
    seed: Number,
    stepsPerFrame: Number,
    wasmUrl: String
  }

  async connect() {
    this.running = false
    this.frame = null
    this.engine = await this.loadEngine()
    if (!this.engine || !this.element.isConnected) return

    this.build()
    if (!this.prefersReducedMotion()) this.play()
  }

  disconnect() {
    this.pause()
    this.discardWorld()
  }

  play() {
    if (this.running || !this.world) return

    this.setRunning(true)
    this.frame = requestAnimationFrame(() => this.tick())
  }

  pause() {
    this.setRunning(false)
    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null
  }

  setRunning(running) {
    this.running = running
    if (this.hasPlayLabelTarget) this.playLabelTarget.textContent = running ? "Pause" : "Play"
  }

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  toggle() {
    this.running ? this.pause() : this.play()
  }

  step() {
    if (!this.world) return

    this.pause()
    this.world.step(1)
    this.draw()
    this.readOut()
  }

  reset() {
    this.seedValue = Math.floor(Math.random() * 2 ** 32)
    this.restart()
  }

  changeSubstrate(event) {
    this.substrateValue = event.target.value
    this.restart()
  }

  changeSpeed(event) {
    this.stepsPerFrameValue = Number(event.target.value)
  }

  async loadEngine() {
    if (!this.wasmUrlValue) {
      this.fail("The simulation build is missing. Run `make wasm` and reload.")
      return null
    }

    try {
      const engine = await import("life_engine")
      await engine.default({ module_or_path: this.wasmUrlValue })
      return engine
    } catch (error) {
      this.fail(`The simulation could not be loaded: ${error.message}`)
      return null
    }
  }

  build() {
    this.discardWorld()
    const params = this.worldsValue[this.substrateValue]
    // The engine takes a u64 seed, which wasm-bindgen maps to a BigInt.
    this.world = new this.engine.World(JSON.stringify(params), BigInt(this.seedValue))

    const width = this.world.width()
    const height = this.world.height()
    this.canvasTarget.width = width
    this.canvasTarget.height = height
    this.canvasContext = this.canvasTarget.getContext("2d")
    this.pixels = new Uint8Array(width * height * 4)
    this.image = new ImageData(new Uint8ClampedArray(this.pixels.buffer), width, height)
    this.metricsEpoch = null
    this.clearStatus()

    this.draw()
    this.readOut()
  }

  // A world owns its cells in the wasm heap and nothing else frees them.
  discardWorld() {
    if (this.world) this.world.free()
    this.world = null
  }

  restart() {
    if (!this.engine) return

    const wasRunning = this.running
    this.pause()
    this.build()
    if (wasRunning) this.play()
  }

  tick() {
    if (!this.running) return

    this.world.step(this.stepsPerFrameValue)
    this.draw()
    this.readOut()
    this.frame = requestAnimationFrame(() => this.tick())
  }

  draw() {
    this.world.render_rgba(this.pixels)
    this.canvasContext.putImageData(this.image, 0, 0)
  }

  readOut() {
    const epoch = Number(this.world.epoch())
    this.epochTarget.textContent = epoch.toLocaleString(LOCALE)
    if (this.metricsEpoch !== null && epoch - this.metricsEpoch < METRICS_EVERY_EPOCHS) return

    const metrics = JSON.parse(this.world.metrics_json())
    this.metricsEpoch = epoch
    this.compressRatioTarget.textContent = metrics.compress_ratio.toFixed(3)
    this.replicatorCountTarget.textContent = metrics.replicator_count.toLocaleString(LOCALE)
    this.distinctTapesTarget.textContent = metrics.distinct_tapes.toLocaleString(LOCALE)
    this.copyRateTarget.textContent = metrics.copy_rate.toFixed(3)
  }

  clearStatus() {
    this.statusTarget.textContent = ""
    this.statusTarget.classList.remove(ERROR_CLASS)
  }

  fail(message) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.add(ERROR_CLASS)
  }
}

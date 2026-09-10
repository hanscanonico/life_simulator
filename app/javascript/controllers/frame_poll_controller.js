import { Controller } from "@hotwired/stimulus"

// Keeps a turbo-frame current without ever reloading the page. It builds no DOM: it only
// asks the frame it is attached to to refetch its own src. The frame must not be
// loading="lazy": Turbo drops a lazy frame's reload() until its first load has settled, so
// an early refetch would silently do nothing.
export default class extends Controller {
  static values = { interval: { type: Number, default: 30000 } }

  connect() {
    this.onVisibilityChange = () => this.visibilityChanged()
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    this.start()
  }

  disconnect() {
    this.stop()
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
  }

  intervalValueChanged() {
    if (this.timer) this.start()
  }

  visibilityChanged() {
    if (document.hidden) return this.stop()

    this.element.reload()
    this.start()
  }

  start() {
    this.stop()
    if (document.hidden) return

    this.timer = setInterval(() => this.element.reload(), this.intervalValue)
  }

  stop() {
    clearInterval(this.timer)
    this.timer = null
  }
}

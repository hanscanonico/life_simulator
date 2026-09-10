import { Controller } from "@hotwired/stimulus"

// The frame refetches in place, so this line is the only clue that the numbers are fresh;
// it has to keep counting between fetches.
export default class extends Controller {
  static values = { datetime: String }

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    this.element.textContent = `updated ${this.elapsed()}`
  }

  elapsed() {
    const seconds = Math.floor((Date.now() - Date.parse(this.datetimeValue)) / 1000)
    if (seconds < 1) return "just now"
    if (seconds < 60) return `${seconds}s ago`

    return `${Math.floor(seconds / 60)}m ago`
  }
}

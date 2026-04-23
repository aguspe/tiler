import { Controller } from "@hotwired/stimulus"

// Tiler clock widget — replaces the inline IIFE that used to live in
// app/views/tiler/widgets/_clock.html.erb. Mirrors the previous formatting
// behavior exactly so widget tests continue to pass.
export default class extends Controller {
  static targets = ["time", "date"]
  static values = {
    format: { type: String, default: "24h" },
    timezone: String
  }

  connect() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  }

  tick() {
    const now = new Date()
    let h = now.getHours()
    const m = now.getMinutes().toString().padStart(2, "0")
    const s = now.getSeconds().toString().padStart(2, "0")
    let suffix = ""
    if (this.formatValue === "12h") {
      suffix = h >= 12 ? " PM" : " AM"
      h = h % 12 || 12
    }
    if (this.hasTimeTarget) {
      this.timeTarget.textContent = `${h.toString().padStart(2, "0")}:${m}:${s}${suffix}`
    }
    if (this.hasDateTarget) {
      this.dateTarget.textContent = now.toLocaleDateString(undefined, {
        weekday: "long", month: "short", day: "numeric"
      })
    }
  }
}

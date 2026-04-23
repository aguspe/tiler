import { Controller } from "@hotwired/stimulus"

// Tiler comments rotator — replaces the inline IIFE that used to live in
// app/views/tiler/widgets/_comments.html.erb. Cycles through .tiler-comment
// items by toggling the .tiler-comment-active class on a timer.
export default class extends Controller {
  static targets = ["item"]
  static values = {
    interval: { type: Number, default: 8 }
  }

  connect() {
    if (this.itemTargets.length <= 1) return
    this.index = 0
    this.timer = setInterval(() => this.advance(), this.intervalValue * 1000)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  advance() {
    if (this.itemTargets.length <= 1) return
    this.itemTargets[this.index].classList.remove("tiler-comment-active")
    this.index = (this.index + 1) % this.itemTargets.length
    this.itemTargets[this.index].classList.add("tiler-comment-active")
  }
}

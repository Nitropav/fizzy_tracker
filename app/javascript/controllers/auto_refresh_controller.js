import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    anchor: String,
    interval: { type: Number, default: 2500 },
    key: String,
    maxAttempts: { type: Number, default: 20 }
  }

  connect() {
    this.storageKey = `auto-refresh:${this.keyValue || window.location.pathname}`
    const attempts = Number(sessionStorage.getItem(this.storageKey) || 0)

    if (attempts >= this.maxAttemptsValue) return

    sessionStorage.setItem(this.storageKey, attempts + 1)
    this.timeout = setTimeout(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  refresh() {
    Turbo.visit(this.urlWithAnchor(), { action: "replace" })
  }

  urlWithAnchor() {
    const url = new URL(window.location.href)

    if (this.hasAnchorValue && this.anchorValue) {
      url.hash = this.anchorValue
    }

    return url.toString()
  }
}

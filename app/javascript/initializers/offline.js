import { Turbo } from "@hotwired/turbo-rails"

if (Current.user && Turbo.offline?.start) {
  Turbo.offline.start("/service-worker.js", {
    scope: "/",
    native: true,
    preload: /\/assets\//
  })
}

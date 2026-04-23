import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

const application = Application.start()
application.debug = false
window.Stimulus = application

// Loading from "controllers" picks up both:
//   - host app controllers in app/javascript/controllers/*    -> identifier = file basename
//   - engine controllers pinned under controllers/tiler/*     -> identifier = "tiler--<name>"
// (Stimulus turns directory separators into double-dashes for nested controllers.)
eagerLoadControllersFrom("controllers", application)

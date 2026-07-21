// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {createLiveToastHook} from "../../deps/live_toast"
import topbar from "../vendor/topbar"

const toastDuration = 3000
const liveToastHook = createLiveToastHook(toastDuration)
const liveToastMounted = liveToastHook.mounted
const liveToastDestroyed = liveToastHook.destroyed

liveToastHook.mounted = function() {
  liveToastMounted.call(this)

  if (this.el.id.startsWith("flash-")) {
    this.dismissTimer = window.setTimeout(() => {
      this.el.querySelector('button[aria-label="close"]')?.click()
    }, toastDuration)
  }
}

liveToastHook.destroyed = function() {
  window.clearTimeout(this.dismissTimer)
  liveToastDestroyed.call(this)
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {LiveToast: liveToastHook},
  params: {
    _csrf_token: csrfToken,
    time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#fd4f00"}, shadowColor: "rgba(253, 79, 0, .18)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Analytics waits until the app is interactive and the browser has idle time.
window.addEventListener("load", () => {
  let loadAnalytics = () => {
    let script = document.createElement("script")
    script.src = "https://cdn.splitbee.io/sb.js"
    script.async = true
    document.head.appendChild(script)
  }

  if ("requestIdleCallback" in window) {
    window.requestIdleCallback(loadAnalytics, {timeout: 2000})
  } else {
    window.setTimeout(loadAnalytics, 1000)
  }
}, {once: true})

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

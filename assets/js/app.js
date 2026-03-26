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
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/projeto_prisma"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

const platformStats = {
  playstation: { percentage: 20, color: "#0070CC" },
  xbox: { percentage: 10, color: "#107C10" },
  steam: { percentage: 60, color: "#66c0f4" },
  retroachievements: { percentage: 10, color: "#D4A017" },
}

function generatePrismaEffect() {
  const beams = {
    "beam-playstation": platformStats.playstation,
    "beam-xbox": platformStats.xbox,
    "beam-steam": platformStats.steam,
    "beam-retro": platformStats.retroachievements,
  }

  Object.entries(beams).forEach(([className, platform]) => {
    const beam = document.querySelector(`.${className}`)
    if (beam) {
      beam.style.opacity = platform.percentage / 100
    }
  })
}

function createPrismaParticles() {
  const prismaBackground = document.querySelector(".prisma-background")
  if (!prismaBackground) return

  prismaBackground.querySelectorAll(".prisma-particle").forEach((node) => node.remove())

  Object.values(platformStats).forEach((platform) => {
    const particleCount = Math.floor(platform.percentage / 5)

    for (let i = 0; i < particleCount; i += 1) {
      const particle = document.createElement("div")
      particle.className = "prisma-particle"
      particle.style.backgroundColor = platform.color
      particle.style.left = `${Math.random() * 100}%`
      particle.style.animationDuration = `${Math.random() * 15 + 10}s`
      particle.style.animationDelay = `${Math.random() * 5}s`
      particle.style.boxShadow = `0 0 10px ${platform.color}`

      prismaBackground.appendChild(particle)
    }
  })
}

window.addEventListener("load", () => {
  generatePrismaEffect()
  createPrismaParticles()
})

function ensurePrismaAlertStack() {
  let stack = document.getElementById("flash-group")
  if (stack) return stack

  stack = document.createElement("div")
  stack.id = "flash-group"
  stack.className = "prisma-alert-stack"
  stack.setAttribute("aria-live", "polite")
  document.body.appendChild(stack)
  return stack
}

function dismissPrismaAlert(alertNode) {
  alertNode.classList.add("prisma-alert-leaving")
  window.setTimeout(() => alertNode.remove(), 220)
}

function createPrismaAlert(detail = {}) {
  const stack = ensurePrismaAlertStack()
  const kind = detail.kind === "error" ? "error" : "info"
  const title = detail.title || (kind === "error" ? "Erro" : "Sucesso")
  const message = detail.message || detail.msg || ""
  const timeout = Number.isFinite(detail.timeout) ? detail.timeout : 4500

  if (!message) return

  const alert = document.createElement("div")
  alert.className = `prisma-alert prisma-alert-${kind}`
  alert.setAttribute("role", "alert")

  const iconWrap = document.createElement("div")
  iconWrap.className = "prisma-alert-icon"
  iconWrap.textContent = kind === "error" ? "!" : "i"

  const copyWrap = document.createElement("div")
  copyWrap.className = "prisma-alert-copy"

  const titleNode = document.createElement("p")
  titleNode.className = "prisma-alert-title"
  titleNode.textContent = title

  const msgNode = document.createElement("p")
  msgNode.className = "prisma-alert-message"
  msgNode.textContent = message

  const closeButton = document.createElement("button")
  closeButton.type = "button"
  closeButton.className = "prisma-alert-close"
  closeButton.setAttribute("aria-label", "fechar alerta")
  closeButton.textContent = "x"
  closeButton.addEventListener("click", () => dismissPrismaAlert(alert))

  copyWrap.appendChild(titleNode)
  copyWrap.appendChild(msgNode)
  alert.appendChild(iconWrap)
  alert.appendChild(copyWrap)
  alert.appendChild(closeButton)
  stack.appendChild(alert)

  if (timeout > 0) {
    window.setTimeout(() => {
      if (alert.isConnected) dismissPrismaAlert(alert)
    }, timeout)
  }
}

window.prismaAlert = (payload) => createPrismaAlert(payload)

window.addEventListener("prisma:alert", (event) => createPrismaAlert(event.detail || {}))
window.addEventListener("phx:prisma_alert", (event) => createPrismaAlert(event.detail || {}))


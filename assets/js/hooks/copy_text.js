export default {
  mounted() {
    this.copyAttempt = 0
    this.glowAnimations = []
    this.content = this.el.querySelector("[data-copy-content]").textContent
    this.copy = async event => {
      const button = event.target.closest("[data-copy-button]")
      if (!button || !this.el.contains(button)) return

      const attempt = ++this.copyAttempt
      this.reset()
      button.disabled = true

      try {
        await navigator.clipboard.writeText(this.content)
        if (attempt !== this.copyAttempt) return
        this.el.querySelector("[data-copy-label]").textContent = "Copied"
        this.el.querySelector("[data-copy-status]").textContent = "Copied to clipboard"
        if (event.detail !== 0 && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
          this.flash()
        }
        this.resetTimer = window.setTimeout(() => this.reset(), 2000)
      } catch {
        if (attempt !== this.copyAttempt) return
        this.el.querySelector("[data-copy-label]").textContent = "Try again"
        const status = this.el.querySelector("[data-copy-status]")
        status.textContent = "Copy didn't work. Select the text and copy it."
        status.classList.remove("sr-only")
        status.classList.add("px-4", "pb-3", "text-xs", "text-muted")
        const fallback = this.el.querySelector("[data-copy-fallback]")
        if (fallback) fallback.hidden = false
      } finally {
        if (attempt === this.copyAttempt) button.disabled = false
      }
    }
    this.el.addEventListener("click", this.copy)
  },

  updated() {
    const content = this.el.querySelector("[data-copy-content]").textContent
    if (content !== this.content) {
      this.copyAttempt++
      this.content = content
      this.reset()
    }
  },

  reset() {
    this.stopGlow()
    window.clearTimeout(this.resetTimer)
    this.el.querySelector("[data-copy-label]").textContent = this.el.dataset.copyIdleLabel
    this.el.querySelector("[data-copy-button]").disabled = false
    const status = this.el.querySelector("[data-copy-status]")
    status.textContent = ""
    status.classList.add("sr-only")
    status.classList.remove("px-4", "pb-3", "text-xs", "text-muted")
    const fallback = this.el.querySelector("[data-copy-fallback]")
    if (fallback) fallback.hidden = true
  },

  flash() {
    const glow = this.el.querySelector("[data-copy-glow]")
    const target = glow.parentElement
    const width = target.clientWidth
    const height = target.clientHeight
    const radius = Math.max(0, parseFloat(window.getComputedStyle(target).borderTopLeftRadius) - 1)
    const left = 1
    const top = 1
    const right = width - 1
    const bottom = height - 1
    const paths = glow.querySelectorAll("path")

    paths[0].setAttribute("d", `M ${left + radius} ${bottom} A ${radius} ${radius} 0 0 1 ${left} ${bottom - radius} V ${top + radius} A ${radius} ${radius} 0 0 1 ${left + radius} ${top} H ${right - radius}`)
    paths[1].setAttribute("d", `M ${left + radius} ${bottom} H ${right - radius} A ${radius} ${radius} 0 0 0 ${right} ${bottom - radius} V ${top + radius} A ${radius} ${radius} 0 0 0 ${right - radius} ${top}`)

    this.glowAnimations = Array.from(paths, path => path.animate([
      {strokeDashoffset: 0.18, opacity: 0},
      {strokeDashoffset: 0.04, opacity: 0.85, offset: 0.12},
      {strokeDashoffset: -0.8, opacity: 0.65, offset: 0.83},
      {strokeDashoffset: -1, opacity: 0}
    ], {duration: 720, easing: "linear"}))
  },

  stopGlow() {
    for (const animation of this.glowAnimations) animation.cancel()
    this.glowAnimations = []
  },

  destroyed() {
    this.copyAttempt++
    this.stopGlow()
    window.clearTimeout(this.resetTimer)
    this.el.removeEventListener("click", this.copy)
  }
}

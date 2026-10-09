export default {
  mounted() {
    this.copyAttempt = 0
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

  destroyed() {
    this.copyAttempt++
    window.clearTimeout(this.resetTimer)
    this.el.removeEventListener("click", this.copy)
  }
}

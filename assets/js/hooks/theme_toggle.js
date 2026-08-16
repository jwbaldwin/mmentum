const POINT_COUNT = 24
const MORPH_DURATION = 480
const PREFERENCES = ["auto", "light", "dark"]
const PREFERENCE_LABELS = {auto: "Auto", light: "Light", dark: "Dark"}

const sunPoints = Array.from({length: POINT_COUNT}, (_, index) => {
  const angle = -Math.PI / 2 + (index / POINT_COUNT) * Math.PI * 2
  const radius = index % 2 === 0 ? 9.25 : 5.55

  return [12 + Math.cos(angle) * radius, 12 + Math.sin(angle) * radius]
})

const moonPoints = [
  ...Array.from({length: 14}, (_, index) => {
    const angle = (-62 - (index / 13) * 236) * (Math.PI / 180)
    return [11.6 + Math.cos(angle) * 8.2, 12 + Math.sin(angle) * 8.2]
  }),
  ...Array.from({length: 10}, (_, index) => {
    const angle = (97.8 + (index / 9) * 164.4) * (Math.PI / 180)
    return [16.5 + Math.cos(angle) * 7.7, 12 + Math.sin(angle) * 7.7]
  })
]

const copyPoints = points => points.map(([x, y]) => [x, y])
const round = value => Math.round(value * 1000) / 1000

const pathThrough = points => {
  const commands = [`M ${round(points[0][0])} ${round(points[0][1])}`]

  for (let index = 0; index < points.length; index++) {
    const previous = points[(index - 1 + points.length) % points.length]
    const current = points[index]
    const next = points[(index + 1) % points.length]
    const afterNext = points[(index + 2) % points.length]
    const firstControl = [
      current[0] + (next[0] - previous[0]) / 7.5,
      current[1] + (next[1] - previous[1]) / 7.5
    ]
    const secondControl = [
      next[0] - (afterNext[0] - current[0]) / 7.5,
      next[1] - (afterNext[1] - current[1]) / 7.5
    ]

    commands.push(
      `C ${round(firstControl[0])} ${round(firstControl[1])} ${round(secondControl[0])} ${round(secondControl[1])} ${round(next[0])} ${round(next[1])}`
    )
  }

  return `${commands.join(" ")} Z`
}

const targetPoints = theme => theme === "dark" ? moonPoints : sunPoints
const easeInOut = progress => progress < 0.5
  ? 4 * progress * progress * progress
  : 1 - Math.pow(-2 * progress + 2, 3) / 2

const ThemeToggle = {
  mounted() {
    this.path = this.el.querySelector("[data-appearance-path]")
    this.icon = this.el.querySelector("[data-appearance-icon]")
    this.track = this.el.querySelector("[data-appearance-track]")
    this.status = this.el.querySelector("[data-appearance-status]")
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.currentPoints = copyPoints(targetPoints(document.documentElement.dataset.theme))
    this.preference = null
    this.turn = 0
    this.path.setAttribute("d", pathThrough(this.currentPoints))

    this.onClick = () => {
      const {preference} = window.mmentumTheme.current()
      const nextPreference = PREFERENCES[(PREFERENCES.indexOf(preference) + 1) % PREFERENCES.length]
      window.mmentumTheme.set(nextPreference, {animate: true})
    }
    this.onThemeChange = event => this.sync(event.detail, true)

    this.el.addEventListener("click", this.onClick)
    window.addEventListener("mmentum:theme-changed", this.onThemeChange)
    this.sync(window.mmentumTheme.current(), false)
    this.readyFrame = window.requestAnimationFrame(() => {
      this.el.dataset.rollReady = "true"
    })
  },

  destroyed() {
    this.el.removeEventListener("click", this.onClick)
    window.removeEventListener("mmentum:theme-changed", this.onThemeChange)
    window.cancelAnimationFrame(this.animationFrame)
    window.cancelAnimationFrame(this.readyFrame)
  },

  sync({preference, theme}, animate) {
    const themeLabel = theme === "dark" ? "Dark" : "Light"
    const preferenceLabel = PREFERENCE_LABELS[preference]
    const nextPreference = PREFERENCES[(PREFERENCES.indexOf(preference) + 1) % PREFERENCES.length]

    this.status.textContent = preference === "auto"
      ? `Auto, system ${themeLabel}`
      : preferenceLabel
    this.el.setAttribute(
      "aria-label",
      `Appearance: ${this.status.textContent}. Switch to ${PREFERENCE_LABELS[nextPreference]}`
    )
    this.icon.dataset.theme = theme

    const nextIndex = PREFERENCES.indexOf(preference)
    if (this.preference === null || !animate) {
      this.turn = nextIndex
    } else if (preference !== this.preference) {
      const previousIndex = PREFERENCES.indexOf(this.preference)
      this.turn += (nextIndex - previousIndex + PREFERENCES.length) % PREFERENCES.length
    }

    this.track.style.setProperty("--appearance-turn", this.turn)
    this.preference = preference

    this.morphTo(theme, animate)
  },

  morphTo(theme, animate) {
    window.cancelAnimationFrame(this.animationFrame)
    const destination = targetPoints(theme)

    if (!animate || this.reduceMotion.matches) {
      this.currentPoints = copyPoints(destination)
      this.path.setAttribute("d", pathThrough(this.currentPoints))
      return
    }

    const origin = copyPoints(this.currentPoints)
    const startedAt = performance.now()

    const drawFrame = now => {
      const progress = Math.min((now - startedAt) / MORPH_DURATION, 1)
      const easedProgress = easeInOut(progress)

      this.currentPoints = origin.map(([x, y], index) => [
        x + (destination[index][0] - x) * easedProgress,
        y + (destination[index][1] - y) * easedProgress
      ])
      this.path.setAttribute("d", pathThrough(this.currentPoints))

      if (progress < 1) this.animationFrame = window.requestAnimationFrame(drawFrame)
    }

    this.animationFrame = window.requestAnimationFrame(drawFrame)
  }
}

export default ThemeToggle

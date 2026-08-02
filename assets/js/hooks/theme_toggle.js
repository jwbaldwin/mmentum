const POINT_COUNT = 24
const MORPH_DURATION = 480

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
    this.status = this.el.querySelector("[data-appearance-status]")
    this.options = [...this.el.querySelectorAll("[data-theme-preference]")]
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.currentPoints = copyPoints(targetPoints(document.documentElement.dataset.theme))
    this.path.setAttribute("d", pathThrough(this.currentPoints))

    this.onOptionClick = event => {
      window.mmentumTheme.set(event.currentTarget.dataset.themePreference, {animate: true})
    }
    this.onThemeChange = event => this.sync(event.detail, true)

    this.options.forEach(option => option.addEventListener("click", this.onOptionClick))
    window.addEventListener("mmentum:theme-changed", this.onThemeChange)
    this.sync(window.mmentumTheme.current(), false)
  },

  destroyed() {
    this.options.forEach(option => option.removeEventListener("click", this.onOptionClick))
    window.removeEventListener("mmentum:theme-changed", this.onThemeChange)
    window.cancelAnimationFrame(this.animationFrame)
  },

  sync({preference, theme}, animate) {
    this.status.textContent = preference === "auto"
      ? `System · ${theme === "dark" ? "Dark" : "Light"}`
      : theme === "dark" ? "Dark" : "Light"
    this.icon.dataset.theme = theme

    this.options.forEach(option => {
      const selected = option.dataset.themePreference === preference
      option.setAttribute("aria-pressed", selected.toString())
    })

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

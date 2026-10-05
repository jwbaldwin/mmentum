(() => {
  const storageKey = "mmentum-theme"
  const systemTheme = window.matchMedia("(prefers-color-scheme: dark)")
  const root = document.documentElement
  const themeColor = document.querySelector('meta[name="theme-color"]')
  let transitionTimer

  const storedPreference = () => {
    const preference = window.localStorage.getItem(storageKey)
    return ["light", "dark"].includes(preference) ? preference : "auto"
  }
  const resolvedTheme = preference => preference === "auto"
    ? systemTheme.matches ? "dark" : "light"
    : preference
  const current = () => ({
    preference: storedPreference(),
    theme: root.dataset.theme
  })
  const apply = (preference, {animate = false, notify = true} = {}) => {
    const theme = resolvedTheme(preference)

    if (animate && root.dataset.theme !== theme) {
      window.clearTimeout(transitionTimer)
      root.classList.add("theme-changing")
      transitionTimer = window.setTimeout(() => root.classList.remove("theme-changing"), 260)
    }

    root.classList.toggle("dark", theme === "dark")
    root.dataset.theme = theme
    root.dataset.themePreference = preference
    root.style.colorScheme = theme
    themeColor.setAttribute("content", theme === "dark" ? "#09090b" : "#ffffff")

    if (notify) {
      window.dispatchEvent(new CustomEvent("mmentum:theme-changed", {
        detail: {preference, theme}
      }))
    }
  }
  const set = (preference, options) => {
    if (preference === "auto") {
      window.localStorage.removeItem(storageKey)
    } else {
      window.localStorage.setItem(storageKey, preference)
    }

    apply(preference, options)
  }

  window.mmentumTheme = {current, set}
  systemTheme.addEventListener("change", () => {
    if (storedPreference() === "auto") apply("auto", {animate: true})
  })
  apply(storedPreference(), {notify: false})
})()

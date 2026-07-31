import tippy from "tippy.js"

const Tooltip = {
  mounted() {
    this.initializeTooltip()
  },

  updated() {
    this.destroyTooltip()
    this.initializeTooltip()
  },

  destroyed() {
    this.destroyTooltip()
  },

  initializeTooltip() {
    const trigger = this.el.firstElementChild

    if (!trigger || this.el.dataset.tooltipDisabled === "true") return

    this.tooltip = tippy(trigger, {
      appendTo: () => document.body,
      arrow: true,
      content: this.el.dataset.tooltipContent,
      delay: [Number(this.el.dataset.tooltipDelay), 0],
      duration: [160, 120],
      maxWidth: 280,
      placement: this.el.dataset.tooltipPlacement,
      theme: "mmentum",
      touch: ["hold", 500]
    })
  },

  destroyTooltip() {
    this.tooltip?.destroy()
    this.tooltip = null
  }
}

export default Tooltip

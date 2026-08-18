import {bisector, extent} from "d3-array"
import {scalePow, scaleTime} from "d3-scale"
import {
  area,
  curveBasis,
  curveCardinal,
  curveCatmullRom,
  curveLinear,
  curveMonotoneX,
  curveNatural,
  curveStep,
  line
} from "d3-shape"
import {timeDay, timeMonth, timeWeek} from "d3-time"
import {momentumChartConfig} from "./momentum_chart_config"

const svgNamespace = "http://www.w3.org/2000/svg"
const dayMilliseconds = 86_400_000
const inspectPoint = bisector(point => point.date).center
const fullDate = new Intl.DateTimeFormat(undefined, {day: "numeric", month: "short", year: "numeric"})
const monthDay = new Intl.DateTimeFormat(undefined, {day: "numeric", month: "short"})
const monthOnly = new Intl.DateTimeFormat(undefined, {month: "short"})
const weekday = new Intl.DateTimeFormat(undefined, {weekday: "short"})

const curveFor = config => {
  switch (config.curve) {
    case "basis": return curveBasis
    case "cardinal": return curveCardinal.tension(config.curveTension)
    case "monotone": return curveMonotoneX
    case "natural": return curveNatural
    case "linear": return curveLinear
    case "step": return curveStep
    default: return curveCatmullRom.alpha(config.curveTension)
  }
}

const rgba = (hex, opacity) => {
  const value = hex.replace("#", "")
  const red = Number.parseInt(value.slice(0, 2), 16)
  const green = Number.parseInt(value.slice(2, 4), 16)
  const blue = Number.parseInt(value.slice(4, 6), 16)
  return `rgba(${red}, ${green}, ${blue}, ${opacity})`
}

const MomentumChart = {
  mounted() {
    this.config = momentumChartConfig
    this.onThemeChange = () => this.render()
    window.addEventListener("mmentum:theme-changed", this.onThemeChange)

    this.resizeObserver = new ResizeObserver(([entry]) => {
      const {height, width} = entry.contentRect
      const sizeChanged = Math.abs(width - this.renderedWidth) > 0.5 ||
        Math.abs(height - this.renderedHeight) > 0.5

      if (sizeChanged) this.render()
    })
    this.resizeObserver.observe(this.el)
    this.render()
  },

  updated() {
    this.render()
  },

  destroyed() {
    this.resizeObserver.disconnect()
    window.removeEventListener("mmentum:theme-changed", this.onThemeChange)
  },

  render() {
    const config = this.config
    this.el.style.height = `${config.chartHeight}px`

    const points = JSON.parse(this.el.dataset.points)
    const width = this.el.clientWidth
    const height = this.el.clientHeight

    if (width === 0 || height === 0 || points.length === 0) return

    this.renderedWidth = width
    this.renderedHeight = height

    const chartPoints = points.map(point => ({
      completion: point.completion,
      date: new Date(point.timestamp),
      score: point.score
    }))
    let [startDate, endDate] = extent(chartPoints, point => point.date)

    if (startDate.getTime() === endDate.getTime()) {
      startDate = new Date(endDate.getTime() - dayMilliseconds)
    }

    const top = config.paddingTop
    const plotBottom = height - config.paddingBottom
    const x = scaleTime()
      .domain([startDate, endDate])
      .range([config.paddingX, width - config.paddingX])
    const y = scalePow()
      .exponent(config.yExponent)
      .domain([0, 100])
      .range([plotBottom, top])
      .clamp(true)
    const curve = curveFor(config)
    const linePath = line()
      .x(point => x(point.date))
      .y(point => y(point.score))
      .curve(curve)(chartPoints)
    const areaPath = area()
      .x(point => x(point.date))
      .y0(plotBottom)
      .y1(point => y(point.score))
      .curve(curve)(chartPoints)
    const latestPoint = chartPoints.at(-1)
    const lineColor = document.documentElement.dataset.theme === "dark"
      ? config.lineColorDark
      : config.lineColorLight

    const shouldReveal = !this.hasRevealed &&
      config.revealDuration > 0 &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const {svg, interaction} = this.buildSvg({
      areaPath,
      shouldReveal,
      chartPoints,
      config,
      endX: x(latestPoint.date),
      endY: y(latestPoint.score),
      endDate,
      height,
      lineColor,
      linePath,
      plotBottom,
      startDate,
      top,
      width,
      x,
      y
    })
    const tooltip = this.buildTooltip()

    this.el.replaceChildren(svg, tooltip)
    this.bindInspection({chartPoints, config, interaction, tooltip, width, x, y})
    this.hasRevealed = true
  },

  buildSvg({
    areaPath,
    shouldReveal,
    chartPoints,
    config,
    endX,
    endY,
    endDate,
    height,
    lineColor,
    linePath,
    plotBottom,
    startDate,
    top,
    width,
    x,
    y
  }) {
    const svg = document.createElementNS(svgNamespace, "svg")
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`)
    svg.setAttribute("preserveAspectRatio", "none")
    svg.setAttribute("role", "img")
    svg.setAttribute("aria-label", this.el.dataset.ariaLabel)
    svg.classList.add("block", "h-full", "w-full", "overflow-visible")

    const definitions = document.createElementNS(svgNamespace, "defs")
    const areaGradientId = `${this.el.id}-area-gradient`
    definitions.append(this.buildAreaGradient(areaGradientId, lineColor, config))

    let strokePaint = lineColor
    if (config.holographicEnabled) {
      const holographicGradientId = `${this.el.id}-holographic-gradient`
      definitions.append(this.buildHolographicGradient(holographicGradientId, config, width, height))
      strokePaint = `url(#${holographicGradientId})`
    }

    const plot = document.createElementNS(svgNamespace, "g")
    if (shouldReveal) {
      const revealClipId = `${this.el.id}-reveal-clip`
      definitions.append(this.buildRevealClip(revealClipId, config.revealDuration, width, height))
      plot.setAttribute("clip-path", `url(#${revealClipId})`)
    }

    const fill = document.createElementNS(svgNamespace, "path")
    fill.setAttribute("d", areaPath)
    fill.setAttribute("fill", `url(#${areaGradientId})`)
    fill.style.display = config.areaEnabled ? "block" : "none"
    fill.style.filter = config.areaBlur > 0 ? `blur(${config.areaBlur}px)` : "none"
    fill.style.mixBlendMode = config.areaBlendMode

    const axis = this.buildTimeAxis({config, endDate, height, lineColor, plotBottom, startDate, x})
    const markers = this.buildCompletionMarkers({chartPoints, config, lineColor, x, y})

    const stroke = document.createElementNS(svgNamespace, "path")
    stroke.setAttribute("d", linePath)
    stroke.setAttribute("fill", "none")
    stroke.setAttribute("stroke", strokePaint)
    stroke.setAttribute("stroke-width", config.lineWidth)
    stroke.setAttribute("stroke-opacity", config.lineOpacity)
    stroke.setAttribute("stroke-linecap", config.lineCap)
    stroke.setAttribute("stroke-linejoin", config.lineJoin)
    stroke.setAttribute("vector-effect", "non-scaling-stroke")
    if (config.dashLength > 0) {
      stroke.setAttribute("stroke-dasharray", `${config.dashLength} ${config.dashGap}`)
    }
    if (config.glowEnabled) {
      stroke.style.filter = `drop-shadow(0 0 ${config.glowBlur}px ${rgba(config.glowColor, config.glowOpacity)})`
    }

    const endpoint = document.createElementNS(svgNamespace, "circle")
    endpoint.setAttribute("cx", endX)
    endpoint.setAttribute("cy", endY)
    endpoint.setAttribute("r", config.endpointSize)
    endpoint.setAttribute("fill", config.holographicEnabled ? lineColor : strokePaint)
    endpoint.style.display = config.endpointVisible ? "block" : "none"

    const hairline = document.createElementNS(svgNamespace, "line")
    hairline.dataset.inspectHairline = "true"
    hairline.setAttribute("y1", top)
    hairline.setAttribute("y2", plotBottom)
    hairline.setAttribute("stroke", lineColor)
    hairline.setAttribute("stroke-opacity", config.hairlineOpacity)
    hairline.setAttribute("visibility", "hidden")

    const inspectedPoint = document.createElementNS(svgNamespace, "circle")
    inspectedPoint.dataset.inspectPoint = "true"
    inspectedPoint.setAttribute("r", config.hoverPointSize)
    inspectedPoint.setAttribute("fill", lineColor)
    inspectedPoint.setAttribute("visibility", "hidden")

    const interaction = document.createElementNS(svgNamespace, "rect")
    interaction.setAttribute("x", config.paddingX)
    interaction.setAttribute("y", top)
    interaction.setAttribute("width", width - config.paddingX * 2)
    interaction.setAttribute("height", plotBottom - top)
    interaction.setAttribute("fill", "transparent")
    interaction.setAttribute("tabindex", config.hoverEnabled ? "0" : "-1")
    interaction.setAttribute("role", "slider")
    interaction.setAttribute("aria-label", "Inspect momentum history")
    interaction.setAttribute("aria-valuemin", "0")
    interaction.setAttribute("aria-valuemax", String(chartPoints.length - 1))
    interaction.style.cursor = config.hoverEnabled ? "crosshair" : "default"
    interaction.style.pointerEvents = config.hoverEnabled ? "all" : "none"

    plot.append(fill, markers, stroke, endpoint)
    svg.append(definitions, axis, plot, hairline, inspectedPoint, interaction)

    return {svg, interaction}
  },

  buildRevealClip(id, duration, width, height) {
    const clip = document.createElementNS(svgNamespace, "clipPath")
    clip.id = id
    clip.setAttribute("clipPathUnits", "userSpaceOnUse")

    const reveal = document.createElementNS(svgNamespace, "rect")
    reveal.setAttribute("x", -32)
    reveal.setAttribute("y", -32)
    reveal.setAttribute("width", 0)
    reveal.setAttribute("height", height + 64)

    const animation = document.createElementNS(svgNamespace, "animate")
    animation.setAttribute("attributeName", "width")
    animation.setAttribute("from", "0")
    animation.setAttribute("to", width + 64)
    animation.setAttribute("dur", `${duration}ms`)
    animation.setAttribute("calcMode", "spline")
    animation.setAttribute("keyTimes", "0;1")
    animation.setAttribute("keySplines", "0.22 1 0.36 1")
    animation.setAttribute("fill", "freeze")

    reveal.append(animation)
    clip.append(reveal)
    return clip
  },

  buildAreaGradient(id, color, config) {
    const gradient = document.createElementNS(svgNamespace, "linearGradient")
    gradient.id = id
    gradient.setAttribute("x1", "0")
    gradient.setAttribute("x2", "0")
    gradient.setAttribute("y1", "0")
    gradient.setAttribute("y2", "1")

    const visibleStop = document.createElementNS(svgNamespace, "stop")
    visibleStop.setAttribute("offset", "0%")
    visibleStop.setAttribute("stop-color", color)
    visibleStop.setAttribute("stop-opacity", config.areaOpacityStart)

    const transparentStop = document.createElementNS(svgNamespace, "stop")
    transparentStop.setAttribute("offset", `${config.areaDepth * 100}%`)
    transparentStop.setAttribute("stop-color", color)
    transparentStop.setAttribute("stop-opacity", config.areaOpacityEnd)

    gradient.append(visibleStop, transparentStop)
    return gradient
  },

  buildHolographicGradient(id, config, width, height) {
    const gradient = document.createElementNS(svgNamespace, "linearGradient")
    const radians = config.holographicAngle * Math.PI / 180
    const horizontal = Math.cos(radians) * width / 2
    const vertical = Math.sin(radians) * height / 2
    gradient.id = id
    gradient.setAttribute("gradientUnits", "userSpaceOnUse")
    gradient.setAttribute("x1", width / 2 - horizontal)
    gradient.setAttribute("y1", height / 2 - vertical)
    gradient.setAttribute("x2", width / 2 + horizontal)
    gradient.setAttribute("y2", height / 2 + vertical)

    const colors = ["#75f4ff", "#a78bfa", "#ff72d2", "#ffd166", "#75f4ff"]
    colors.forEach((color, index) => {
      const stop = document.createElementNS(svgNamespace, "stop")
      stop.setAttribute("offset", `${index / (colors.length - 1) * 100}%`)
      stop.setAttribute("stop-color", color)
      stop.setAttribute("stop-opacity", config.holographicIntensity)
      gradient.append(stop)
    })

    return gradient
  },

  buildTimeAxis({config, endDate, height, lineColor, plotBottom, startDate, x}) {
    const axis = document.createElementNS(svgNamespace, "g")
    axis.setAttribute("aria-hidden", "true")
    axis.style.display = config.axisVisible ? "block" : "none"

    this.timeTicks(startDate, endDate, config.targetTickCount).forEach((tick, index, ticks) => {
      const tickX = x(tick.date)
      const mark = document.createElementNS(svgNamespace, "line")
      mark.setAttribute("x1", tickX)
      mark.setAttribute("x2", tickX)
      mark.setAttribute("y1", plotBottom + 7)
      mark.setAttribute("y2", plotBottom + 7 + config.tickLength)
      mark.setAttribute("stroke", lineColor)
      mark.setAttribute("stroke-opacity", config.tickOpacity)

      const label = document.createElementNS(svgNamespace, "text")
      label.setAttribute("x", tickX)
      label.setAttribute("y", height - 3)
      label.setAttribute("fill", lineColor)
      label.setAttribute("fill-opacity", config.labelOpacity)
      label.setAttribute("font-size", config.labelSize)
      label.setAttribute("font-family", "inherit")
      label.setAttribute("text-anchor", index === 0 ? "start" : index === ticks.length - 1 ? "end" : "middle")
      label.textContent = tick.label

      axis.append(mark, label)
    })

    return axis
  },

  timeTicks(startDate, endDate, targetTickCount) {
    const durationDays = Math.max(1, (endDate - startDate) / dayMilliseconds)
    const intervals = Math.max(1, targetTickCount - 1)
    let interval
    let formatter

    if (durationDays <= 21) {
      interval = timeDay.every(Math.max(1, Math.ceil(durationDays / intervals)))
      formatter = durationDays <= 7 ? weekday : monthDay
    } else if (durationDays <= 120) {
      interval = timeWeek.every(Math.max(1, Math.ceil(durationDays / 7 / intervals)))
      formatter = monthDay
    } else {
      interval = timeMonth.every(Math.max(1, Math.ceil(durationDays / 30.44 / intervals)))
      formatter = monthOnly
    }

    const interiorTicks = interval.range(interval.ceil(startDate), endDate)
    const ticks = [startDate, ...interiorTicks, endDate]
      .filter((date, index, dates) => index === 0 || date.getTime() !== dates[index - 1].getTime())

    return ticks.map((date, index) => ({
      date,
      label: index === ticks.length - 1 ? "Today" : formatter.format(date)
    }))
  },

  buildCompletionMarkers({chartPoints, config, lineColor, x, y}) {
    const markers = document.createElementNS(svgNamespace, "g")
    markers.setAttribute("aria-hidden", "true")
    markers.style.display = config.completionMarkersVisible ? "block" : "none"

    chartPoints.filter(point => point.completion).forEach(point => {
      const marker = document.createElementNS(svgNamespace, "circle")
      marker.setAttribute("cx", x(point.date))
      marker.setAttribute("cy", y(point.score))
      marker.setAttribute("r", config.completionMarkerSize)
      marker.setAttribute("fill", lineColor)
      marker.setAttribute("fill-opacity", config.completionMarkerOpacity)
      markers.append(marker)
    })

    return markers
  },

  buildTooltip() {
    const tooltip = document.createElement("div")
    tooltip.className = "pointer-events-none absolute z-30 hidden rounded-control bg-zinc-950 px-2.5 py-1.5 text-xs font-medium text-zinc-50 shadow-control dark:bg-zinc-100 dark:text-zinc-950"
    tooltip.setAttribute("role", "tooltip")
    return tooltip
  },

  bindInspection({chartPoints, config, interaction, tooltip, width, x, y}) {
    if (!config.hoverEnabled) return

    const svg = interaction.ownerSVGElement
    const hairline = svg.querySelector("[data-inspect-hairline]")
    const inspectedPoint = svg.querySelector("[data-inspect-point]")
    let inspectedIndex = chartPoints.length - 1

    const showPoint = index => {
      inspectedIndex = Math.max(0, Math.min(chartPoints.length - 1, index))
      const point = chartPoints[inspectedIndex]
      const pointX = x(point.date)
      const pointY = y(point.score)

      hairline.setAttribute("x1", pointX)
      hairline.setAttribute("x2", pointX)
      hairline.setAttribute("visibility", "visible")
      inspectedPoint.setAttribute("cx", pointX)
      inspectedPoint.setAttribute("cy", pointY)
      inspectedPoint.setAttribute("visibility", "visible")

      if (config.tooltipEnabled) {
        tooltip.textContent = `${fullDate.format(point.date)} · ${Math.round(point.score)}`
        tooltip.classList.remove("hidden")
        const tooltipWidth = tooltip.offsetWidth
        const tooltipLeft = Math.max(0, Math.min(width - tooltipWidth, pointX - tooltipWidth / 2))
        tooltip.style.left = `${tooltipLeft}px`
        tooltip.style.top = `${Math.max(0, pointY - 36)}px`
      }

      interaction.setAttribute("aria-valuenow", String(inspectedIndex))
      interaction.setAttribute(
        "aria-valuetext",
        `${fullDate.format(point.date)}, momentum ${Math.round(point.score)} out of 100`
      )
    }

    const hidePoint = () => {
      hairline.setAttribute("visibility", "hidden")
      inspectedPoint.setAttribute("visibility", "hidden")
      tooltip.classList.add("hidden")
    }

    interaction.addEventListener("pointermove", event => {
      const bounds = interaction.getBoundingClientRect()
      const chartX = (event.clientX - bounds.left) / bounds.width * (width - config.paddingX * 2) + config.paddingX
      showPoint(inspectPoint(chartPoints, x.invert(chartX)))
    })
    interaction.addEventListener("pointerleave", hidePoint)
    interaction.addEventListener("focus", () => showPoint(inspectedIndex))
    interaction.addEventListener("blur", hidePoint)
    interaction.addEventListener("keydown", event => {
      if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return

      event.preventDefault()
      showPoint(inspectedIndex + (event.key === "ArrowLeft" ? -1 : 1))
    })
  }
}

export default MomentumChart

import {extent} from "d3-array"
import {scaleLinear, scaleTime} from "d3-scale"
import {area, curveBasis, line} from "d3-shape"

const svgNamespace = "http://www.w3.org/2000/svg"
const curve = curveBasis

const MomentumChart = {
  mounted() {
    this.resizeObserver = new ResizeObserver(() => this.render())
    this.resizeObserver.observe(this.el)
    this.render()
  },

  updated() {
    this.render()
  },

  destroyed() {
    this.resizeObserver.disconnect()
  },

  render() {
    const points = JSON.parse(this.el.dataset.points)
    const width = this.el.clientWidth
    const height = this.el.clientHeight

    if (width === 0 || height === 0 || points.length === 0) return

    const chartPoints = points.map(point => ({
      date: new Date(point.timestamp),
      score: point.score
    }))
    const [startDate, endDate] = extent(chartPoints, point => point.date)
    const top = 10
    const bottom = height - 12
    const x = scaleTime().domain([startDate, endDate]).range([12, width - 12])
    const y = scaleLinear().domain([0, 100]).range([bottom, top])
    const linePath = line()
      .x(point => x(point.date))
      .y(point => y(point.score))
      .curve(curve)(chartPoints)
    const areaPath = area()
      .x(point => x(point.date))
      .y0(bottom)
      .y1(point => y(point.score))
      .curve(curve)(chartPoints)
    const gradientId = `${this.el.id}-gradient`
    const latestPoint = chartPoints.at(-1)

    this.el.replaceChildren(this.buildSvg({
      areaPath,
      endX: x(latestPoint.date),
      endY: y(latestPoint.score),
      gradientId,
      height,
      linePath,
      width
    }))
  },

  buildSvg({areaPath, endX, endY, gradientId, height, linePath, width}) {
    const svg = document.createElementNS(svgNamespace, "svg")
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`)
    svg.setAttribute("preserveAspectRatio", "none")
    svg.setAttribute("role", "img")
    svg.setAttribute("aria-label", this.el.dataset.ariaLabel)
    svg.classList.add("block", "h-full", "w-full", "overflow-visible")

    const definitions = document.createElementNS(svgNamespace, "defs")
    const gradient = document.createElementNS(svgNamespace, "linearGradient")
    gradient.id = gradientId
    gradient.setAttribute("x1", "0")
    gradient.setAttribute("x2", "0")
    gradient.setAttribute("y1", "0")
    gradient.setAttribute("y2", "1")

    const visibleStop = document.createElementNS(svgNamespace, "stop")
    visibleStop.setAttribute("offset", "0%")
    visibleStop.setAttribute("stop-color", "currentColor")
    visibleStop.setAttribute("stop-opacity", "0.24")

    const transparentStop = document.createElementNS(svgNamespace, "stop")
    transparentStop.setAttribute("offset", "100%")
    transparentStop.setAttribute("stop-color", "currentColor")
    transparentStop.setAttribute("stop-opacity", "0")

    gradient.append(visibleStop, transparentStop)
    definitions.append(gradient)

    const fill = document.createElementNS(svgNamespace, "path")
    fill.setAttribute("d", areaPath)
    fill.setAttribute("fill", `url(#${gradientId})`)

    const stroke = document.createElementNS(svgNamespace, "path")
    stroke.setAttribute("d", linePath)
    stroke.setAttribute("fill", "none")
    stroke.setAttribute("stroke", "currentColor")
    stroke.setAttribute("stroke-width", "2.5")
    stroke.setAttribute("stroke-linecap", "round")
    stroke.setAttribute("stroke-linejoin", "round")
    stroke.setAttribute("vector-effect", "non-scaling-stroke")

    const endpoint = document.createElementNS(svgNamespace, "circle")
    endpoint.setAttribute("cx", endX)
    endpoint.setAttribute("cy", endY)
    endpoint.setAttribute("r", "4.5")
    endpoint.setAttribute("fill", "currentColor")

    svg.append(definitions, fill, stroke, endpoint)
    return svg
  }
}

export default MomentumChart

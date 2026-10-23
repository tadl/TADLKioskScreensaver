import { Controller } from "@hotwired/stimulus"
import "chart"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { labels: Array, values: Array }

  connect() {
    const brandBlue = getComputedStyle(this.element).getPropertyValue("--color-tadl-600").trim()
    this.chart = new window.Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [{ label: "Sessions", data: this.valuesValue, borderColor: brandBlue, backgroundColor: `${brandBlue}12`, fill: true, tension: 0.15, pointRadius: 2 }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: !window.matchMedia("(prefers-reduced-motion: reduce)").matches,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true, ticks: { precision: 0 } } }
      }
    })
  }

  disconnect() { this.chart?.destroy() }
}

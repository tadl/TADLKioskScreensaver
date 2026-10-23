import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["start", "end"]

  preset(event) {
    const option = event.target.selectedOptions[0]
    if (option.value === "custom") return
    this.startTarget.value = option.dataset.start
    this.endTarget.value = option.dataset.end
    this.apply()
  }

  custom() { this.element.querySelector("[name=preset_range]").value = "custom" }
  apply() { this.element.requestSubmit() }
}

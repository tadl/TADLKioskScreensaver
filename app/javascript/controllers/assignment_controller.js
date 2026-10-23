import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option"]

  filter(event) {
    const query = event.target.value.trim().toLocaleLowerCase()
    this.optionTargets.forEach(option => {
      option.hidden = !option.dataset.label.includes(query)
    })
  }
}

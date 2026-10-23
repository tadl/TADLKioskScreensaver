import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["all", "item", "count"]

  connect() { this.update() }

  toggleAll(event) {
    this.itemTargets.forEach(item => { item.checked = event.target.checked })
    this.update()
  }

  update() {
    const count = this.itemTargets.filter(item => item.checked).length
    this.countTarget.textContent = count
    if (this.hasAllTarget) {
      this.allTarget.checked = this.itemTargets.length > 0 && count === this.itemTargets.length
      this.allTarget.indeterminate = count > 0 && count < this.itemTargets.length
    }
  }
}

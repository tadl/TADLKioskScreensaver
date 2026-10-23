import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "avatar"]

  connect() {
    // An image can fail before Stimulus has attached its error listener.
    if (this.hasAvatarTarget && this.avatarTarget.complete && this.avatarTarget.naturalWidth === 0) {
      this.avatarFailed()
    }
  }

  avatarFailed() { this.avatarTarget.hidden = true }

  clickOutside(event) {
    if (!this.element.contains(event.target)) this.element.open = false
  }

  focusOut(event) {
    if (event.relatedTarget && !this.element.contains(event.relatedTarget)) this.element.open = false
  }

  closeWithEscape() {
    if (!this.element.open) return
    this.element.open = false
    this.triggerTarget.focus()
  }
}

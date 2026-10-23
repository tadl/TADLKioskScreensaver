import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    const message = event.submitter?.dataset.confirm
    if (message && !window.confirm(message)) event.preventDefault()
  }
}

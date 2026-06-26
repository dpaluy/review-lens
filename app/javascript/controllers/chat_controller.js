import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  fill(event) {
    this.inputTarget.value = event.params.question
    this.inputTarget.focus()
  }

  fireBlocked(event) {
    this.inputTarget.value = event.params.question
    this.element.querySelector("form").requestSubmit()
  }

  onKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      event.target.closest("form").requestSubmit()
    }
  }
}

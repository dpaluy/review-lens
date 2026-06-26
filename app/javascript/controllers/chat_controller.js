import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  onKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (this.thinking) return

      event.target.closest("form").requestSubmit()
    }
  }

  disableWhileThinking(event) {
    event.target.closest("#product_chat_form").querySelectorAll("input, button").forEach((element) => {
      element.disabled = true
    })
  }

  get thinking() {
    return document.getElementById("product_chat_pending") || this.inputTarget.disabled
  }
}

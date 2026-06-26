import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "chevron"]
  static values = { open: Boolean }

  connect() {
    if (this.hasContentTarget) {
      this.contentTarget.hidden = !this.openValue
    }
    this._updateChevron()
  }

  toggle() {
    this.openValue = !this.openValue
    if (this.hasContentTarget) {
      this.contentTarget.hidden = !this.openValue
    }
    this._updateChevron()
  }

  _updateChevron() {
    if (this.hasChevronTarget) {
      this.chevronTarget.style.transform = this.openValue ? "rotate(180deg)" : ""
    }
  }
}

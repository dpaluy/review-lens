import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["urlSection", "csvSection", "urlBtn", "csvBtn", "modeInput", "urlInput"]

  connect() {
    const currentMode = this.modeInputTarget.value
    if (currentMode === "manual") {
      this._activate(this.csvBtnTarget, this.urlBtnTarget)
      this.urlSectionTarget.hidden = true
      this.csvSectionTarget.hidden = false
    } else {
      this.showUrl()
    }
  }

  showUrl() {
    this.urlSectionTarget.hidden = false
    this.csvSectionTarget.hidden = true
    this.modeInputTarget.value = "url"
    this._activate(this.urlBtnTarget, this.csvBtnTarget)
  }

  showCsv() {
    this.urlSectionTarget.hidden = true
    this.csvSectionTarget.hidden = false
    this.modeInputTarget.value = "manual"
    this._activate(this.csvBtnTarget, this.urlBtnTarget)
  }

  fillSample() {
    if (this.hasUrlInputTarget) {
      this.urlInputTarget.value = "https://www.trustpilot.com/review/quickbooks.intuit.com"
      this.urlInputTarget.focus()
    }
  }

  _activate(on, off) {
    const onStyle = "flex:1;padding:7px 10px;border:none;border-radius:7px;font-size:13px;font-weight:500;cursor:pointer;background:#fff;color:#16191d;box-shadow:0 1px 2px rgba(0,0,0,0.10);"
    const offStyle = "flex:1;padding:7px 10px;border:none;border-radius:7px;font-size:13px;font-weight:500;cursor:pointer;background:transparent;color:#6b7280;"
    on.style.cssText = onStyle
    off.style.cssText = offStyle
  }
}

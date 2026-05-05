import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "image", "input", "fileName", "placeholder" ]

  previewImage() {
    if (this.#file) {
      this.imageTarget.src = URL.createObjectURL(this.#file)
      this.imageTarget.onload = () => URL.revokeObjectURL(this.imageTarget.src)
    }
  }

  previewFileName() {
    this.#file ? this.#showFileName() : this.#showPlaceholder()
  }

  #showFileName() {
    this.fileNameTarget.innerText = this.#files.length > 1 ? `${this.#files.length} files selected` : this.#file.name
    this.fileNameTarget.removeAttribute("hidden")
    this.placeholderTarget.setAttribute("hidden", true)
  }

  #showPlaceholder() {
    this.placeholderTarget.removeAttribute("hidden")
    this.fileNameTarget.setAttribute("hidden", true)
  }

  get #file() {
    return this.inputTarget.files[0]
  }

  get #files() {
    return Array.from(this.inputTarget.files)
  }
}

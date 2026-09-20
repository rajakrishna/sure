import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { src: String };
  static targets = ["frame"];

  load() {
    if (!this.hasFrameTarget || !this.srcValue) return;
    if (this.frameTarget.getAttribute("src")) return;

    this.frameTarget.setAttribute("src", this.srcValue);
  }
}

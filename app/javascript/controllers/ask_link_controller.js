import { Controller } from "@hotwired/stimulus";

// Desktop: keep the turbo-frame + open-rail contract.
// Narrow viewports: drop the frame and visit /chats/new so Ask actually
// submits on the Assistant page instead of targeting a hidden rail.
export default class extends Controller {
  open(event) {
    if (this.#isDesktop()) return;

    event.preventDefault();
    event.stopImmediatePropagation();

    const href = this.element.getAttribute("href");
    if (!href) return;

    Turbo.visit(href, { frame: "_top" });
  }

  #isDesktop() {
    return window.matchMedia("(min-width: 1024px)").matches;
  }
}

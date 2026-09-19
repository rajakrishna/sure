import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "input", "item"];
  static values = { open: { type: Boolean, default: false } };

  connect() {
    this._onKeydown = this.onKeydown.bind(this);
    document.addEventListener("keydown", this._onKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown);
  }

  onKeydown(event) {
    const metaK = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k";
    if (metaK) {
      event.preventDefault();
      this.toggle();
    }
    if (event.key === "Escape" && this.openValue) {
      this.close();
    }
  }

  toggle() {
    this.openValue ? this.close() : this.open();
  }

  open() {
    this.openValue = true;
    this.dialogTarget.showModal();
    this.inputTarget.value = "";
    this.filter();
    this.inputTarget.focus();
  }

  close() {
    this.openValue = false;
    if (this.dialogTarget.open) this.dialogTarget.close();
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase();
    this.itemTargets.forEach((item) => {
      const haystack = item.dataset.commandPaletteSearchValue || item.textContent;
      item.hidden = query !== "" && !haystack.toLowerCase().includes(query);
    });
  }
}

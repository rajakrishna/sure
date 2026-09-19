import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "input",
    "chips",
    "contextField",
    "fileInput",
    "picker",
    "pickerList",
    "pickerSearch",
    "commands",
    "fileName",
  ];
  static values = {
    catalog: { type: Object, default: {} },
    seed: { type: Array, default: [] },
  };

  connect() {
    this.items = [];
    this.seedValue.forEach((item) => this.#addItem(item, { silent: true }));
    this.#renderChips();
    this.#syncContextField();
    this.#notifyChat();
  }

  togglePicker(event) {
    event?.preventDefault();
    this.#togglePanel("picker");
    if (!this.pickerTarget.classList.contains("hidden")) {
      this.pickerSearchTarget.value = "";
      this.#renderPicker("");
      this.pickerSearchTarget.focus();
    }
  }

  toggleCommands(event) {
    event?.preventDefault();
    this.#togglePanel("commands");
  }

  closePanels() {
    this.pickerTarget.classList.add("hidden");
    this.commandsTarget.classList.add("hidden");
  }

  filterPicker() {
    this.#renderPicker(this.pickerSearchTarget.value);
  }

  selectPickerItem(event) {
    const button = event.currentTarget;
    this.#addItem({
      type: button.dataset.type,
      id: button.dataset.id,
      name: button.dataset.name,
      subtitle: button.dataset.subtitle,
    });
    this.closePanels();
    this.inputTarget.focus();
  }

  insertCommand(event) {
    event.preventDefault();
    const prompt = event.currentTarget.dataset.prompt;
    if (!prompt) return;

    this.inputTarget.value = prompt;
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }));
    this.closePanels();
    this.inputTarget.focus();
  }

  handleInput() {
    const value = this.inputTarget.value;
    const cursor = this.inputTarget.selectionStart ?? value.length;
    const before = value.slice(0, cursor);
    const trigger = before.match(/([/@])([^\s/@]*)$/);

    if (!trigger) {
      if (
        !this.pickerTarget.classList.contains("hidden") ||
        !this.commandsTarget.classList.contains("hidden")
      ) {
        this.closePanels();
      }
      return;
    }

    if (trigger[1] === "@") {
      this.commandsTarget.classList.add("hidden");
      this.pickerTarget.classList.remove("hidden");
      this.pickerSearchTarget.value = trigger[2];
      this.#renderPicker(trigger[2]);
    } else if (trigger[1] === "/") {
      this.pickerTarget.classList.add("hidden");
      this.commandsTarget.classList.remove("hidden");
    }
  }

  addPageContext(event) {
    event?.preventDefault();
    const path = window.location.pathname;
    const matchers = [
      [ /\/accounts\/([0-9a-f-]+)/i, "account" ],
      [ /\/transactions\/([0-9a-f-]+)/i, "transaction" ],
      [ /\/bills\/([0-9a-f-]+)/i, "bill" ],
      [ /\/goals\/([0-9a-f-]+)/i, "goal" ],
    ];

    for (const [pattern, type] of matchers) {
      const match = path.match(pattern);
      if (!match) continue;

      const item = this.#catalogItems().find(
        (entry) => entry.type === type && entry.id === match[1],
      );
      if (item) {
        this.#addItem(item);
        return;
      }
    }
  }

  openFilePicker(event) {
    event?.preventDefault();
    this.fileInputTarget.click();
  }

  handleFileChange() {
    const files = Array.from(this.fileInputTarget.files || []);
    if (!files.length) {
      this.fileNameTarget.textContent = "";
      this.fileNameTarget.classList.add("hidden");
      return;
    }

    this.fileNameTarget.textContent = files.map((file) => file.name).join(", ");
    this.fileNameTarget.classList.remove("hidden");
    this.#notifyChat();
  }

  removeChip(event) {
    const index = Number(event.currentTarget.dataset.index);
    this.items.splice(index, 1);
    this.#renderChips();
    this.#syncContextField();
    this.#notifyChat();
  }

  #togglePanel(name) {
    const picker = this.pickerTarget;
    const commands = this.commandsTarget;

    if (name === "picker") {
      const opening = picker.classList.contains("hidden");
      picker.classList.toggle("hidden", !opening);
      commands.classList.add("hidden");
    } else {
      const opening = commands.classList.contains("hidden");
      commands.classList.toggle("hidden", !opening);
      picker.classList.add("hidden");
    }
  }

  #addItem(item, { silent } = {}) {
    if (!item?.type || !item?.id) return;
    if (this.items.some((existing) => existing.type === item.type && existing.id === item.id)) {
      return;
    }

    this.items.push({
      type: item.type,
      id: item.id,
      name: item.name,
      subtitle: item.subtitle,
    });

    if (!silent) {
      this.#renderChips();
      this.#syncContextField();
      this.#notifyChat();
    }
  }

  #renderChips() {
    if (!this.hasChipsTarget) return;

    this.chipsTarget.innerHTML = "";
    this.chipsTarget.classList.toggle("hidden", this.items.length === 0);

    this.items.forEach((item, index) => {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.dataset.index = String(index);
      chip.dataset.action = "chat-composer#removeChip";
      chip.className =
        "inline-flex items-center gap-1 rounded-full bg-surface-inset px-2 py-0.5 text-xs text-primary";
      chip.textContent = item.name || item.type;
      this.chipsTarget.appendChild(chip);
    });
  }

  #syncContextField() {
    if (!this.hasContextFieldTarget) return;
    this.contextFieldTarget.value = JSON.stringify(
      this.items.map(({ type, id }) => ({ type, id })),
    );
  }

  #renderPicker(query) {
    const normalized = (query || "").trim().toLowerCase();
    const matches = this.#catalogItems().filter((item) => {
      if (!normalized) return true;
      return `${item.name} ${item.subtitle}`.toLowerCase().includes(normalized);
    });

    this.pickerListTarget.innerHTML = "";

    matches.slice(0, 20).forEach((item) => {
      const button = document.createElement("button");
      button.type = "button";
      button.dataset.action = "chat-composer#selectPickerItem";
      button.dataset.type = item.type;
      button.dataset.id = item.id;
      button.dataset.name = item.name;
      button.dataset.subtitle = item.subtitle || "";
      button.className =
        "flex w-full flex-col items-start rounded-md px-2 py-1.5 text-left hover:bg-container-hover";
      button.innerHTML = `<span class="text-sm text-primary">${this.#escape(item.name)}</span><span class="text-xs text-secondary">${this.#escape(item.subtitle || item.type)}</span>`;
      this.pickerListTarget.appendChild(button);
    });
  }

  #notifyChat() {
    if (!this.hasInputTarget) return;
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }));
  }

  #catalogItems() {
    const catalog = this.catalogValue || {};
    return [
      ...(catalog.accounts || []),
      ...(catalog.transactions || []),
      ...(catalog.bills || []),
      ...(catalog.goals || []),
    ];
  }

  #escape(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;");
  }
}

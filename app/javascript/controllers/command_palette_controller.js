import { Controller } from "@hotwired/stimulus";

const FOCUSABLE_SELECTOR = [
  "a[href]:not([hidden])",
  "button:not([disabled])",
  "textarea:not([disabled])",
  "input:not([disabled]):not([type=hidden])",
  "select:not([disabled])",
  "[tabindex]:not([tabindex='-1'])",
].join(", ");

const QUESTION_PREFIX =
  /^(what|why|how|when|where|who|which|is|are|can|should|could|would|will|do|does|did|explain|ask|show|list|find|help)\b/i;

export default class extends Controller {
  static targets = ["dialog", "input", "item", "askItem", "openChatItem", "askLabel", "openChatLabel"];
  static values = {
    open: { type: Boolean, default: false },
    askPath: { type: String, default: "/chats/new" },
  };

  connect() {
    this._onKeydown = this.onKeydown.bind(this);
    this._priorFocus = null;
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
      return;
    }
    if (event.key === "Escape" && this.openValue) {
      event.preventDefault();
      this.close();
      return;
    }
    if (this.openValue && event.key === "Tab") {
      this.#trapFocus(event);
    }
  }

  toggle() {
    this.openValue ? this.close() : this.open();
  }

  open() {
    this._priorFocus = document.activeElement;
    this.openValue = true;
    this.dialogTarget.showModal();
    this.inputTarget.value = "";
    this.filter();
    this.inputTarget.focus();
  }

  close() {
    this.openValue = false;
    if (this.dialogTarget.open) this.dialogTarget.close();
    this.#restoreFocus();
  }

  clickOutside(event) {
    if (event.target === this.dialogTarget) {
      this.close();
    }
  }

  filter() {
    const query = this.inputTarget.value.trim();
    const haystackQuery = query.toLowerCase();

    this.itemTargets.forEach((item) => {
      const haystack = item.dataset.commandPaletteSearchValue || item.textContent;
      item.hidden = haystackQuery !== "" && !haystack.toLowerCase().includes(haystackQuery);
    });

    this.#updateAskItems(query);
  }

  #updateAskItems(query) {
    const showAsk = query.length > 0;
    if (this.hasAskItemTarget) this.askItemTarget.hidden = !showAsk;
    if (this.hasOpenChatItemTarget) this.openChatItemTarget.hidden = !showAsk;
    if (!showAsk) return;

    const askHref = this.#askHref(query, true);
    const openHref = this.#askHref(query, false);

    const askLink = this.askItemTarget.querySelector("a");
    const openLink = this.openChatItemTarget.querySelector("a");
    if (askLink) askLink.href = askHref;
    if (openLink) openLink.href = openHref;

    if (this.hasAskLabelTarget) {
      this.askLabelTarget.textContent = query;
    }
    if (this.hasOpenChatLabelTarget) {
      this.openChatLabelTarget.textContent = query;
    }

    if (this.#looksLikeQuestion(query)) {
      this.askItemTarget.classList.add("bg-container-inset");
    } else if (this.hasAskItemTarget) {
      this.askItemTarget.classList.remove("bg-container-inset");
    }
  }

  #askHref(query, autoSubmit) {
    const url = new URL(this.askPathValue, window.location.origin);
    url.searchParams.set("message_hint", query);
    if (autoSubmit) url.searchParams.set("auto_submit", "1");
    return `${url.pathname}${url.search}`;
  }

  #looksLikeQuestion(query) {
    return query.endsWith("?") || QUESTION_PREFIX.test(query);
  }

  #trapFocus(event) {
    const focusables = this.#focusables();
    if (focusables.length === 0) {
      event.preventDefault();
      return;
    }
    const first = focusables[0];
    const last = focusables[lastIndex(focusables)];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  #focusables() {
    return Array.from(this.dialogTarget.querySelectorAll(FOCUSABLE_SELECTOR)).filter((el) => {
      if (el.closest("[hidden]")) return false;
      return el.offsetParent !== null || el === document.activeElement;
    });
  }

  #restoreFocus() {
    const prior = this._priorFocus;
    this._priorFocus = null;
    if (prior && typeof prior.focus === "function" && document.body.contains(prior)) {
      prior.focus();
    }
  }
}

function lastIndex(items) {
  return items.length - 1;
}

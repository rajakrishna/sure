import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["rule", "handle"];
  static values = { url: String };

  dragStart(event) {
    this.draggedElement = event.currentTarget;
    this.draggedElement.classList.add("opacity-50");
    event.dataTransfer.effectAllowed = "move";
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("opacity-50");
  }

  dragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";

    const afterElement = this.getDragAfterElement(event.clientY);
    if (afterElement == null) {
      this.element.appendChild(this.draggedElement);
    } else {
      this.element.insertBefore(this.draggedElement, afterElement);
    }
  }

  drop(event) {
    event.preventDefault();
    this.saveOrder();
  }

  getDragAfterElement(y) {
    const elements = this.ruleTargets.filter((rule) => rule !== this.draggedElement);
    return elements.reduce(
      (closest, child) => {
        const box = child.getBoundingClientRect();
        const offset = y - box.top - box.height / 2;
        if (offset < 0 && offset > closest.offset) {
          return { offset, element: child };
        }
        return closest;
      },
      { offset: Number.NEGATIVE_INFINITY },
    ).element;
  }

  async saveOrder() {
    const ruleIds = this.ruleTargets.map((rule) => rule.dataset.ruleId);
    const csrfToken = document.querySelector('meta[name="csrf-token"]');
    if (!csrfToken || !this.urlValue) return;

    await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": csrfToken.content,
      },
      body: JSON.stringify({ rule_ids: ruleIds }),
    });
  }
}

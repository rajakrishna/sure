import assert from "node:assert/strict";
import test from "node:test";

import { buildCategoryTransactionsUrl } from "../../../app/javascript/utils/transactions_filter_url.mjs";

test("builds a transactions deep link with category and date range", () => {
  const url = buildCategoryTransactionsUrl({
    filterValue: "Groceries",
    startDate: "2026-05-01",
    endDate: "2026-05-31",
  });
  assert.equal(
    url,
    "/transactions?q%5Bcategories%5D%5B%5D=Groceries&q%5Bstart_date%5D=2026-05-01&q%5Bend_date%5D=2026-05-31",
  );
});

test("encodes category names with special characters", () => {
  const url = buildCategoryTransactionsUrl({
    filterValue: "Food & Drink",
    startDate: "2026-05-01",
    endDate: "2026-05-31",
  });
  assert.match(url, /q%5Bcategories%5D%5B%5D=Food\+%26\+Drink/);
});

test("passes the Uncategorized sentinel through unchanged, not a display name", () => {
  const url = buildCategoryTransactionsUrl({
    filterValue: "__uncategorized__",
    startDate: "2026-05-01",
    endDate: "2026-05-31",
  });
  assert.match(url, /q%5Bcategories%5D%5B%5D=__uncategorized__/);
});

test("omits date params when dates are blank", () => {
  const url = buildCategoryTransactionsUrl({
    filterValue: "Groceries",
    startDate: "",
    endDate: "",
  });
  assert.equal(url, "/transactions?q%5Bcategories%5D%5B%5D=Groceries");
});

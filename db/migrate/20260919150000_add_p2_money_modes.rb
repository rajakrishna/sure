class AddP2MoneyModes < ActiveRecord::Migration[8.1]
  def change
    add_column :budgets, :flex_budgeted, :decimal, precision: 19, scale: 4, default: 0, null: false
    add_check_constraint :budgets, "flex_budgeted >= 0", name: "chk_budgets_flex_budgeted_non_negative"

    add_reference :goals, :funding_category, type: :uuid, foreign_key: { to_table: :categories, on_delete: :nullify }, index: true
  end
end

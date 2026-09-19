class AddCopilotReviewIntelligence < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :reviewed_at, :datetime
    add_column :transactions, :reviewed_by_id, :uuid
    add_index :transactions, :reviewed_at
    add_index :transactions, :reviewed_by_id

    add_column :categories, :emoji, :string
    add_column :categories, :exclude_from_budget, :boolean, default: false, null: false

    add_column :insights, :feedback, :string

    add_column :families, :investment_benchmark_symbol, :string, default: "SPY"
    add_column :families, :high_confidence_auto_apply, :boolean, default: false, null: false
    add_column :families, :ai_review_gate_threshold, :integer, default: 10, null: false

    create_table :custom_alerts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.jsonb :config, default: {}, null: false
      t.boolean :enabled, default: true, null: false
      t.datetime :last_triggered_at
      t.timestamps
    end

    add_index :custom_alerts, [ :family_id, :kind ]
  end
end

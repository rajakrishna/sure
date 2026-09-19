class AddP3WealthPolish < ActiveRecord::Migration[8.1]
  def change
    add_reference :transactions, :assignee, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }, index: true

    create_table :saved_reports, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.jsonb :config, null: false, default: {}
      t.timestamps
    end
    add_index :saved_reports, [ :family_id, :name ]

    create_table :advisor_invites, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :email
      t.string :name
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_viewed_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :advisor_invites, :token_digest, unique: true
    add_index :advisor_invites, [ :family_id, :revoked_at ]

    create_table :financial_health_scores, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.integer :score, null: false
      t.jsonb :components, null: false, default: {}
      t.jsonb :actions, null: false, default: []
      t.datetime :generated_at, null: false
      t.timestamps
    end
    add_index :financial_health_scores, [ :family_id, :generated_at ]

    create_table :forecast_explains, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.integer :horizon_days, null: false, default: 30
      t.jsonb :projection, null: false, default: {}
      t.text :narration
      t.datetime :generated_at, null: false
      t.timestamps
    end
    add_index :forecast_explains, [ :family_id, :generated_at ]
  end
end

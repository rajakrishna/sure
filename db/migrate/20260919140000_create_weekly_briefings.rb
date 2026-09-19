class CreateWeeklyBriefings < ActiveRecord::Migration[8.1]
  def change
    create_table :weekly_briefings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.date :week_of, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :generated_at, null: false
      t.timestamps
    end

    add_index :weekly_briefings, [ :family_id, :week_of ], unique: true
  end
end

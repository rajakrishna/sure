class CreateAiProposals < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_proposals, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true
      t.references :chat, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :source, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.string :function_name
      t.jsonb :payload, null: false, default: {}
      t.string :target_type
      t.uuid :target_id
      t.datetime :reviewed_at
      t.uuid :reviewed_by_id
      t.timestamps
    end

    add_index :ai_proposals, [ :family_id, :status ]
    add_index :ai_proposals, [ :chat_id, :status ]
    add_index :ai_proposals, [ :family_id, :kind, :target_id ],
      unique: true,
      where: "status = 'pending' AND target_id IS NOT NULL",
      name: "index_ai_proposals_unique_pending_target"
    add_foreign_key :ai_proposals, :users, column: :reviewed_by_id
  end
end

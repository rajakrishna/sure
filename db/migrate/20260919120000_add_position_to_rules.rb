class AddPositionToRules < ActiveRecord::Migration[7.2]
  def up
    add_column :rules, :position, :integer

    execute <<~SQL
      UPDATE rules
      SET position = numbered.pos
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY family_id ORDER BY created_at ASC, id ASC) AS pos
        FROM rules
      ) numbered
      WHERE rules.id = numbered.id
    SQL

    change_column_null :rules, :position, false
    add_index :rules, [ :family_id, :position ]
  end

  def down
    remove_index :rules, [ :family_id, :position ]
    remove_column :rules, :position
  end
end

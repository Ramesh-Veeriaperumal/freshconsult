class CreateSolutionTemplates < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :solution_templates do |t|
      t.integer :id, limit: 8, null: false
      t.integer :account_id, limit: 8, null: false
      t.string :title, null: false
      t.text :description, limit: 16.megabytes + 1
      t.integer :user_id, limit: 8, null: false
      t.integer :modified_by, limit: 8
      t.timestamp :modified_at
      t.boolean :is_active, default: true
      t.boolean :is_default, default: false
      t.timestamps
      t.integer :folder_id, limit: 8
      t.integer :int_01, limit: 8
      t.integer :int_02, limit: 8
      t.text :text_01
      t.text :text_02
    end

    add_index :solution_templates, [:account_id], name: 'index_solution_templates_on_acc_id'
  end

  def down
    drop_table :solution_templates
  end
end

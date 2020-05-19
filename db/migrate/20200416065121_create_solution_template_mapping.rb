class CreateSolutionTemplateMapping < ActiveRecord::Migration
  shard :all

  def up
    create_table :solution_template_mappings do |t|
      t.integer :id, limit: 8, null: false
      t.integer :account_id, limit: 8, null: false
      t.integer :used_cnt, limit: 8, null: false
      t.integer :article_id, limit: 8, null: false
      t.integer :template_id, limit: 8, null: false
      t.timestamps
    end

    add_index :solution_template_mappings, [:account_id], name: 'index_solution_template_mappings_on_acc_id'
    add_index :solution_template_mappings, [:account_id, :article_id, :template_id], name: 'index_solution_template_mappings_on_acc_article_template_id'
  end

  def down
    drop_table :solution_template_mappings
  end
end

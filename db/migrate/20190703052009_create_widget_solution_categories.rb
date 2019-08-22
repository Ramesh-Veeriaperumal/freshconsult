class CreateHelpWidgetSolutionCategories < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :help_widget_solution_categories do |t|
      t.column :help_widget_id, 'bigint unsigned'
      t.column :solution_category_meta_id, 'bigint unsigned'
      t.column :account_id, 'bigint unsigned'
      t.integer :position
      t.timestamps
    end

    add_index 'help_widget_solution_categories', ['account_id', 'help_widget_id', 'solution_category_meta_id'], name: 'index_help_widget_solution_category_on_account_widget_id_meta_id'
  end

  def self.down
    drop_table :help_widget_solution_categories
  end
end

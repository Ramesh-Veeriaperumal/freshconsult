class CreateDashboardWidgets < ActiveRecord::Migration
  
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :dashboard_widgets do |t|
      t.integer :account_id, :limit => 8
      t.string :name
      t.integer :widget_type
      t.text :grid_config
      t.integer :dashboard_id, :limit => 8
      t.integer :ticket_filter_id, :limit => 8
      t.text :config_data
      t.integer :refresh_interval
      t.boolean :active, :default => true, :null => false

      t.timestamps
    end
  end

  def down
    drop_table :dashboard_widgets
  end
end

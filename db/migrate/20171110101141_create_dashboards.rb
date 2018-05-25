class CreateDashboards < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :dashboards do |t|
      t.integer :account_id, :limit => 8
      t.string :name
      t.boolean :deleted, :default => false, :null => false

      t.timestamps
    end
  end

  def down
  	drop_table :dashboards
  end
end

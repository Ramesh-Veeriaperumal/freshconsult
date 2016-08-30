class CreateStatusGroups < ActiveRecord::Migration
  shard :all

  def self.up
    create_table :status_groups do |t|
      t.column   :status_id, "bigint unsigned", :null => false
      t.column   :group_id, "bigint unsigned", :null => false
      t.column   :account_id, "bigint unsigned", :null => false
      t.timestamps
    end

    add_index(:status_groups, [:account_id, :status_id])
  end

  def self.down
    drop_table :status_groups
  end
end

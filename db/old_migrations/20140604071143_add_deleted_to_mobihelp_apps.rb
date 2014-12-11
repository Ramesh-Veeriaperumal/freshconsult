class AddDeletedToMobihelpApps < ActiveRecord::Migration
	shard :all
  def self.up
    add_column :mobihelp_apps, :deleted, :boolean, :default => false
    remove_index :mobihelp_apps, column: [:account_id, :name, :platform]
    add_index :mobihelp_apps, [:account_id, :name, :platform]
  end

  def self.down
    remove_column :mobihelp_apps, :deleted
    remove_index :mobihelp_apps, column: [:account_id, :name, :platform]
    add_index :mobihelp_apps, [:account_id, :name, :platform], :unique => true
  end
end

class AddDeltaToSearchTables < ActiveRecord::Migration
  def self.up
    add_column :customers, :delta, :boolean, :default => true, :null => false
    add_column :helpdesk_tickets, :delta, :boolean, :default => true, :null => false
    add_column :topics, :delta, :boolean, :default => true, :null => false
    add_column :users, :delta, :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :users, :delta
    remove_column :topics, :delta
    remove_column :helpdesk_tickets, :delta
    remove_column :customers, :delta
  end
end

class AddImportIdToCustomers < ActiveRecord::Migration
  def self.up
    add_column :customers, :import_id, :integer
    add_column :users, :import_id, :integer
    add_column :groups, :import_id, :integer
    add_column :helpdesk_tickets, :import_id, :integer 
    add_column :forum_categories, :import_id, :integer 
    add_column :forums, :import_id, :integer
    add_column :topics, :import_id, :integer    
    
  end
 

  def self.down
    remove_column :customers, :import_id
    remove_column :users, :import_id
    remove_column :helpdesk_tickets, :import_id
    remove_column :forum_categories, :import_id
    remove_column :forums, :import_id
    remove_column :topics, :import_id
    remove_column :groups, :import_id    
    
  end
end

class AddNoteToCustomer < ActiveRecord::Migration
  def self.up
    add_column :customers, :note, :text
    add_column :customers, :domains, :text
    remove_column :customers, :phone
    remove_column :customers, :address
    remove_column :customers, :website
    remove_column :customers, :owner_id
    remove_column :customers, :cust_type
    
  end

  def self.down
    
    remove_column :customers, :note
    remove_column :customers, :domains
    add_column :customers, :phone, :string
    add_column :customers, :address, :string
    add_column :customers, :website, :string
    add_column :customers, :owner_id, :integer
    add_column :customers, :cust_type, :integer
    
  end
end

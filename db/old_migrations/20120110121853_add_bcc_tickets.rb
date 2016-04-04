class AddBccTickets < ActiveRecord::Migration
  def self.up
    
    add_column :email_configs, :bcc_email, :string 
    
  end

  def self.down
    remove_column :email_configs, :bcc_email
  end
end

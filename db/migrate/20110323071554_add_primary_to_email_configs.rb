class AddPrimaryToEmailConfigs < ActiveRecord::Migration
  def self.up
    add_column :email_configs, :primary_role, :boolean, :default => false
    
    execute <<-SQL
      INSERT INTO email_configs 
        (account_id, to_email, reply_email, created_at, primary_role) 
        SELECT id, default_email, default_email, created_at, 1 FROM accounts
    SQL
    
    remove_column :accounts, :default_email
  end

  def self.down
    add_column :accounts, :default_email, :string
    remove_column :email_configs, :primary_role
  end
end

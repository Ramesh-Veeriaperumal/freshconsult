class CreateAdminAccountForAllAccounts < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account_admin = account.admins.first
  	  account_admin.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:account_admin] 
  		account_admin.save!
    end
  end

  def self.down    
  end
    
end

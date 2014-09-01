class PopulateAccountConfigurations < ActiveRecord::Migration
  
  def self.up
		
		Account.find_in_batches(:include => "account_admin", :batch_size => 500) do |accounts|
			accounts.each do |account|
				admin = account.account_admin
				account.create_account_configuration( 
					{ 
						:contact_info => { :first_name => admin.first_name, 
																:last_name => admin.last_name,
																:email => admin.email, 
																:phone => admin.phone },
						:billing_emails => { :invoice_emails => [ admin.email ] }
					} 
				)
			end
		end

  end

  def self.down
		AccountConfiguration.destroy_all
  end
end

class EnableGoogleSigninForDisabledAccounts < ActiveRecord::Migration
	shard :all

  def self.up
  	count = 0
		Sharding.run_on_shard("shard_2") do
			puts "Entering a Shard"
			Account.find_in_batches(:batch_size => 300, :conditions => ['id > ?',123353]) do |accounts|
				count = count + 1
				accounts.each do |account|
					acc = Account.find(account.id)
					acc.make_current
					if !acc.features?(:google_signin)
						acc.features.google_signin.create
						puts "Google signin feature enabled: #{acc.id}"
					end
				end
				Account.reset_current_account
			end
			puts "Batch #{count} done"
		end
  end

  def self.down
  end
end

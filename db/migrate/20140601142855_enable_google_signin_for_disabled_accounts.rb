class EnableGoogleSigninForDisabledAccounts < ActiveRecord::Migration
	shard :all

  def self.up
  	count = 0
		Sharding.run_on_all_shards do
			puts "Entering a Shard"
			Subscription.find_in_batches(:batch_size => 300, :conditions => ["account_id > ?", 1]) do |subscriptions|
				count = count + 1
				subscriptions.each do |s|
					account = Account.find(s.account_id)
					account.make_current
					if !account.features?(:google_signin)
						account.features.google_signin.create
						puts "Google signin feature enabled: #{account.id}"
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

class EnableGoogleSigninForDisabledAccounts < ActiveRecord::Migration
	shard :all

  def self.up
  	ShardMapping.find_in_batches(:batch_size => 300) do |shards|
			shards.each do |shard|
				Sharding.select_shard_of shard.account_id do
					acc = Account.find shard.account_id
					acc.make_current
					if !acc.features?(:google_signin)
						acc.features.google_signin.create
						puts "Google signin feature enabled: #{acc.id}"
					end
				end
				Account.reset_current_account
			end
		end
  end

  def self.down
  end
end

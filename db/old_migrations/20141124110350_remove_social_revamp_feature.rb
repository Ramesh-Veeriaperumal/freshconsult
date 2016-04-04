class RemoveSocialRevampFeature < ActiveRecord::Migration 
  shard :none
  def self.up
    ShardMapping.find_in_batches(:batch_size => 300) do |shards|
      shards.each do |shard|
        Sharding.select_shard_of(shard.account_id) do
          begin
            account = Account.find shard.account_id
            account.make_current
            account.features.send(:social_revamp).destroy if account.features_included?(:social_revamp)
          rescue Exception => e
            puts "#{shard.account_id} - #{e.message}"
          ensure
            Account.reset_current_account
          end
        end
      end
    end  
  end
  
end




class PopulateChatFeatureData < ActiveRecord::Migration
  shard :all
  def self.up
    Sharding.run_on_all_shards do
      Account.find_in_batches(:batch_size => 300) do |accounts|
        accounts.each do |account|
          account.make_current
          account.features.chat_enable.create if account.features.chat.available?
          Account.reset_current_account
        end
      end
    end
  end

  def self.down
    Sharding.run_on_all_shards do
      Account.find_in_batches(:batch_size => 300) do |accounts|
        accounts.each do |account|
          account.make_current
          account.features.chat_enable.destroy
          Account.reset_current_account
        end
      end
    end
  end
end
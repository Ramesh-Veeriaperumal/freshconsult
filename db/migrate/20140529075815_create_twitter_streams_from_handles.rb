class CreateTwitterStreamsFromHandles < ActiveRecord::Migration
  shard :all
  
  def self.up
    Sharding.run_on_all_shards do
      Account.active_accounts.each do |account|
        account.make_current
        handles = account.twitter_handles
        handles.each do |handle|
          next if handle.default_stream
          handle.populate_streams
          streams = handle.twitter_streams
          streams.each do  |stream|
            stream.populate_accessible(Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]) if stream.custom_stream?
          end
        end  
      end
    end
  end

  def self.down
  end
end

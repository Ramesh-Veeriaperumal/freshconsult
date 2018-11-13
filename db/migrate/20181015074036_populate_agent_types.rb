class PopulateAgentTypes < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    account_ids = []
    Sharding.run_on_all_shards do
      Account.find_each(batch_size: 500) do |account|
        begin
          account.make_current
          AgentType.create_support_agent_type(account)
        rescue Exception => e
          account_ids << account.id
        end
      end
    end
    Rails.logger.info "Populating agent type failed for accounts: #{account_ids.join(",")}"
    account_ids
  end

  def down
  end
end

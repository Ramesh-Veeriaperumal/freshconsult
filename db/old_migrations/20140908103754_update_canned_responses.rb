class UpdateCannedResponses < ActiveRecord::Migration
  shard :all
  def self.up
    failed_accounts = []
    ShardMapping.find_in_batches(:batch_size => 300) do |shards|      
      shards.each do |shard|
        Account.reset_current_account
        begin
          Sharding.select_shard_of(shard.account_id) do
            account = Account.find(shard.account_id)
            next if account.nil?
            account.make_current
            canned_responses = account.canned_responses
            canned_responses.each do |response|
              if response.helpdesk_accessible.nil?
                if response.accessible.visibility == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
                  helpdesk_accessible = response.create_helpdesk_accessible(:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups])
                  helpdesk_accessible.create_group_accesses(response.accessible.group_id)
                elsif response.accessible.visibility == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
                  response.create_helpdesk_accessible(:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all])
                else
                  helpdesk_accessible = response.create_helpdesk_accessible(:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
                  helpdesk_accessible.create_user_accesses(response.accessible.user_id)
                end
              end
            end 
          end
        rescue Exception => e
          puts ":::::::::::#{e}:::::::::::::"
          failed_accounts << shard.account_id
        end
      end      
    end
    puts failed_accounts.inspect
    failed_accounts
  end
end

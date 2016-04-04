class UpdateTicketFilterAccesses < ActiveRecord::Migration
	shard :all

  def self.up
  	failed_accounts = []
    Account.find_in_batches(:batch_size => 300) do |accounts|
      accounts.each do |account|
        begin
          Sharding.select_shard_of(account.id) do
            next if account.nil?
            account.make_current
            ticket_filters = account.ticket_filters
            ticket_filters.each do |filter|
              if filter.helpdesk_accessible.nil?
                if filter.accessible.visibility == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
                  helpdesk_accessible = filter.create_helpdesk_accessible(:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups])
                  helpdesk_accessible.create_group_accesses(filter.accessible.group_id)
                elsif filter.accessible.visibility == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
                  filter.create_helpdesk_accessible(:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all])
                else
                  helpdesk_accessible = filter.create_helpdesk_accessible(:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
                  helpdesk_accessible.create_user_accesses(filter.accessible.user_id)
                end
              end
            end 
          end
        rescue Exception => e
          puts ":::::::::::#{e}:::::::::::::"
          failed_accounts << account.id
        end
      end      
    end
    puts failed_accounts.inspect
    failed_accounts
 	end
end

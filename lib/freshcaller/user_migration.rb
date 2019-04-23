module Freshcaller
  module UserMigration
    def fetch_freshfone_groups
      groups = []
      account = ::Account.current
      account.groups.find_in_batches(batch_size: 10) do |group_batch|
        group_batch.each do |group|
          group_hash = { name: group.name, description: group.description, agent_emails: [] }
          group.agents.each do |agent|
            group_hash[:agent_emails] << agent.email
          end
          groups << group_hash
        end
      end
      File.open("#{account_migration_location}/groups.json", 'w') do |f|
        f.write(groups.to_json)
      end
      Rails.logger.info "Group migration for account :: #{account.id} completed"
    end

    def fetch_freshfone_users
      account = ::Account.current
      account_admin.make_current
      account.agents.full_time_support_agents.find_in_batches(batch_size: 10) do |agent_batch|
        agent_batch.each do |agent|
          agent.update_attribute(:freshcaller_enabled, true) unless agent.freshcaller_agent
        end
      end
      Rails.logger.info "User migration for account :: #{account.id} completed"
    end
  end
end

module Freshcaller
  module UserMigration
    def fetch_freshfone_groups(account_id)
      groups = []
      Sharding.select_shard_of(account_id) do
        Sharding.run_on_slave do
          account = ::Account.find(account_id)
          if account.present? && account.groups.present?
            account.make_current
            account.groups.each do |group|
              group_hash = { name: group.name, description: group.description, agent_emails: [] }
              group.agents.each do |agent|
                group_hash[:agent_emails] << agent.email
              end
              groups << group_hash
            end
          end
        end
      end
      File.open("#{account_migration_location}/groups.json", 'w') do |f|
        f.write(groups.to_json)
      end
      Rails.logger.info "Group migration for account :: #{account_id} completed"
      ::Account.reset_current_account
    end

    def fetch_freshfone_users(account_id)
      Sharding.select_shard_of(account_id) do
        Sharding.run_on_slave do
          account = ::Account.find(account_id)
          account_admin.make_current
          if account.present? && account.users.present?
            account.make_current
            account.agents.each do |agent|
              next if agent == account_admin.agent
              agent.update_attribute(:freshcaller_enabled, true)
            end
          end
        end
      end
      Rails.logger.info "User migration for account :: #{account_id} completed"
      ::Account.reset_current_account
    end
  end
end

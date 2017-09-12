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
      users = []
      Sharding.select_shard_of(account_id) do
        Sharding.run_on_slave do
          account = ::Account.find(account_id)
          if account.present? && account.users.present?
            account.make_current
            account.users.each do |user|
              users << build_user_hash(user)
            end
          end
        end
      end
      File.open("#{account_migration_location}/users.json", 'w') do |f|
        f.write(users.to_json)
      end
      Rails.logger.info "User migration for account :: #{account_id} completed"
      ::Account.reset_current_account
    end

    private

      def roles_hash
        { 'Account Administrator' => 'Account Admin',
          'Administrator' => 'Admin', 'Supervisor' => 'Supervisor',
          'Agent' => 'Agent' }
      end

      def build_user_hash(user)
        role = current_account.roles.where(privileges: user.privileges).first
        user_hash = { name: user.name, email: user.email }
        user_hash[:role] = if role.present? && role.default_role?
                             roles_hash[role.name]
                           elsif role.present? && role.custom_role?
                             find_custom_role(role)
                           end
        user_hash
      end

      def find_custom_role(role)
        if role.privilege?(:manage_account) && role.privilege?(:admin_tasks)
          roles_hash['Account Administrator']
        elsif role.privilege?(:admin_tasks)
          roles_hash['Administrator']
        else
          roles_hash['Agent']
        end
      end
  end
end

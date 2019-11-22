class AddCreatAndEditArticleAndApproveArticlePrivileges < ActiveRecord::Migration
  UPDATE_WITH_PRIVILEGES = [:untitled_solution_agent_1, :untitled_solution_agent_2].freeze

  def self.up
    Sharding.run_on_all_shards do
      puts "#{Thread.current[:shard_selection].shard}..."
      AccountIterator.each(joins: :subscription, conditions: [" subscriptions.state != 'suspended' "]) do |account|
        account.roles.where('default_role is false Or name="Field Technician"').each do |role|
          if role.privilege?(:publish_solution)
            role.privilege_list = role.abilities | UPDATE_WITH_PRIVILEGES
          end
          role.save!
        end
      end
    end
  end

  def self.down
    Sharding.run_on_all_shards do
      puts "#{Thread.current[:shard_selection].shard}..."
      AccountIterator.each(joins: :subscription, conditions: [" subscriptions.state != 'suspended' "]) do |account|
        account.roles.where('default_role is false Or name="Field Technician"').each do |role|
          if role.privilege?(:publish_solution)
            role.privilege_list = role.abilities - UPDATE_WITH_PRIVILEGES
            role.save!
          end
        end
      end
    end
  end
end

# Below script we will run for delta updates on roles
#
# Sharding.run_on_all_shards do
#   UPDATE_WITH_PRIVILEGES = [:create_and_edit_article, :approve_article].freeze
#   pre_migration_time = '2019-11-28'
#   Role.where("(default_role is false Or name='Field Technician') and updated_at >= '#{pre_migration_time}' " ).find_each do |role|
#     ac_id = role.account_id
#     account = Account.find(ac_id)
#     account.make_current
#     begin
#       if role.privilege?(:publish_solution) && !role.privilege?(:create_and_edit_article)
#       	role.privilege_list = role.abilities | UPDATE_WITH_PRIVILEGES
#       	role.save!
#     end
#     rescue => e
#       puts "Role with id #{role.id} and with name #{role.name} for account_id #{account.id} has not been migrated due to #{e.message}"
#     end
#   end
# end

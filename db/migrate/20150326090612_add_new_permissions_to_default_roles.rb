class AddNewPermissionsToDefaultRoles < ActiveRecord::Migration
  shard :all

  DEFAULT_ROLE_PRIVILEGES = {
    "Account Administrator" => Helpdesk::Roles::ACCOUNT_ADMINISTRATOR,
    "Administrator" => Helpdesk::Roles::ADMINISTRATOR,
    "Supervisor" => Helpdesk::Roles::SUPERVISOR,
    "Agent" => Helpdesk::Roles::AGENT
  }


  def up
    failed_accounts = []
    ShardMapping.find_in_batches(:batch_size => 300) do |shards|
      shards.each do |shard|
        Account.reset_current_account
        begin
          Sharding.select_shard_of(shard.account_id) do
            account = Account.find_by_id(shard.account_id)
            next if account.nil?
            account.make_current
            account.roles.where(:default_role=>true).each do |role|
              next if role.name == "Restricted Agent"
              role.privilege_list=DEFAULT_ROLE_PRIVILEGES.fetch(role.name)
              role.save
            end
          end
        rescue Exception => e
          puts ":::::::::::#{e}:::::::::::::"
          failed_accounts << shard.account_id
          next
        end
      end
      puts failed_accounts.inspect
    end
  end

  def down
    #  failed_accounts = []
    #  ShardMapping.find_in_batches(:batch_size => 300) do |shards|
    #   shards.each do |shard|
    #     Account.reset_current_account
    #     begin
    #       Sharding.select_shard_of(shard.account_id) do
    #         account = Account.find(shard.account_id)
    #         next if account.nil?
    #         account.make_current
    #   		  account.roles.where(:default_role=>true).each do |role|
    #   		  	privilege_data=DEFAULT_ROLE_PRIVILEGES.fetch(role.name)
    #           role.update_attribute(:privileges,Role.privileges_mask(privilege_data).to_s)
    #   			end
    #   		end
    #     rescue Exception => e
    #      puts ":::::::::::#{e}:::::::::::::"
    #      failed_accounts << shard.account_id
    #      next
    #     end
    #   end
    #   puts failed_accounts.inspect
    # end
  end

end

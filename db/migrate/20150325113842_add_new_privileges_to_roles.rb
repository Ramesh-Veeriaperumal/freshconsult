class AddNewPrivilegesToRoles < ActiveRecord::Migration
  shard :all
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
            account.roles.where(:default_role=>false).each do |role|
              role.privilege_list=role.abilities
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
    # will retain privileges.yml and priveleges_map.rb after revert..
    failed_accounts = []
    ShardMapping.find_in_batches(:batch_size => 300) do |shards|
      shards.each do |shard|
        Account.reset_current_account
        begin
          Sharding.select_shard_of(shard.account_id) do
            account = Account.find_by_id(shard.account_id)
            account.make_current
            account.roles.each do |role|
              role.privilege_list = role.abilities - Helpdesk::PrivilegesMap::MIGRATION_MAP.values.flatten
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
end

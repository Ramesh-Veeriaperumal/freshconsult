class AddTagPrivilegesToRoles < ActiveRecord::Migration
  
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end
 
  def self.up
    Account.active_accounts.find_each do |account|
      begin
        account.make_current
        account.roles.where("default_role = false OR (name = 'Restricted Agent' AND default_role = true)").each do |role|
          privilege_data = role.abilities
          Helpdesk::PrivilegesMap::MIGRATION_MAP.each do |key, value|
            privilege_data.concat(value) if privilege_data.include?(key)
          end
          role.privileges = Role.privileges_mask(privilege_data.uniq).to_s
          puts ":::::::::::Migrating for acount #{account.id} :::::::::::::"
          role.save
        end
      rescue => e
        puts ":::::::::::exception:::::::::::::"
        puts "account_id :: #{account.id} exception :: #{e}"
      ensure
        Account.reset_current_account
      end
    end
  end
  
end

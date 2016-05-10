class ChangeSupervisorRoleDescription < ActiveRecord::Migration
  shard :all
  include Helpdesk::Roles

  def self.up
    failed_accounts = []
    Account.reset_current_account
    Account.find_each do |account|
      next if account.nil?
      begin
        account.make_current
        role = account.roles.supervisor.first
        if role
          role.description = DEFAULT_ROLES_LIST[2][2]
          role.save
        end
      rescue Exception => e
        puts "::::::::::: Migration Failed :: Account id => #{account.id}, Exception => #{e}:::::::::::::"
        failed_accounts << account.id
      ensure
        Account.reset_current_account
      end
    end
    puts failed_accounts.inspect
  end

  def self.down
    failed_accounts = []
    Account.reset_current_account
    Account.find_each do |account|
      next if account.nil?
      begin
        account.make_current
        role = account.roles.supervisor.first
        if role
          role.description = "Can perform all agent related activities and access reports, but cannot access or change configurations in the Admin tab."
          role.save
        end
      rescue Exception => e
        puts "::::::::::: Reverting the migration failed :: Account id => #{account.id}, Exception => #{e}:::::::::::::"
        failed_accounts << account.id
      ensure
        Account.reset_current_account
      end
    end
    puts failed_accounts.inspect
  end

end

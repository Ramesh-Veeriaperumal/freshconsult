class ConvertSharedOwnershipFeatureToBitmap < ActiveRecord::Migration
  shard :all

  def up
    failed_accounts = {}
    Account.active_accounts.readonly(false).find_each do |account|
      begin
        account.make_current
        next unless account.shared_ownership_enabled?
        account.enable_setting(:shared_ownership)
      rescue => e
        failed_accounts[account.id] = e.message
      ensure
        Account.reset_current_account
      end
    end
    puts "failed_accounts = #{failed_accounts.inspect}"
  end

  def down
    failed_accounts = {}
    Account.active_accounts.find_each do |account|
      begin
        account.make_current
        next unless account.account.shared_ownership_enabled?
        account.enable_setting(:shared_ownership)
      rescue => e
        failed_accounts[account.id] = e.message
      ensure
        Account.reset_current_account
      end
    end
    puts "failed_accounts = #{failed_accounts.inspect}"
  end

end
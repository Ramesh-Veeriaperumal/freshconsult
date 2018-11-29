class MoveCascadeDispatcherToBitmap < ActiveRecord::Migration
  shard :all

  def up
    failed_accounts = {}
    Account.active_accounts.readonly(false).find_each do |account|
      begin
        account.make_current
        next unless account.features?(:cascade_dispatchr)
        account.add_feature(:cascade_dispatcher)
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
        next unless account.has_feature?(:cascade_dispatcher)
        account.features.cascade_dispatchr.create
      rescue => e
        failed_accounts[account.id] = e.message
      ensure
        Account.reset_current_account
      end
    end
    puts "failed_accounts = #{failed_accounts.inspect}"
  end

  def verify_db_feature_with_bitmap_feature
    both_db_and_bitmap_feature_count = 0
    only_db_feature = []
    only_bitmap_feature = []
    failed_accounts = {}
    Sharding.run_on_all_slaves do
      Account.active_accounts.find_each do |account|
        begin
          account.make_current
          if account.features?(:cascade_dispatchr) && account.has_feature?(:cascade_dispatcher)
            both_db_and_bitmap_feature_count += 1
          elsif account.features?(:cascade_dispatchr)
            only_db_feature << account.id
          elsif account.has_feature?(:cascade_dispatcher)
            only_bitmap_feature << account.id
          end
        rescue => e
          failed_accounts[account.id] = e.message
        ensure
          Account.reset_current_account
        end
      end
    end
    puts "both_db_and_bitmap_feature_count = #{both_db_and_bitmap_feature_count}"
    puts "only_db_feature = #{only_db_feature.inspect}"
    puts "only_bitmap_feature = #{only_bitmap_feature.inspect}"
    puts "failed_accounts = #{failed_accounts.inspect}"
  end
end